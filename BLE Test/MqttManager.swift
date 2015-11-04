//
//  MqttManager.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 30/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import Foundation
import Moscapsule

protocol MqttManagerDelegate : class {
    func onMqttConnected()
    func onMqttDisconnected()
    func onMqttMessageReceived(message : String, topic: String)
    func onMqttError(message : String)
}

class MqttManager
{
    enum ConnectionStatus {
        case Connecting
        case Connected
        case Disconnecting
        case Disconnected
        case Error
        case None
    }
    
    enum MqttQos : Int  {
        case AtMostOnce = 0
        case AtLeastOnce = 1
        case ExactlyOnce = 2
    }
    
    // Singleton
    static let sharedInstance = MqttManager()
    
    // Constants
    private static let defaultKeepAliveInterval : Int32 = 60;
    
    // Data
    weak var delegate : MqttManagerDelegate?
    var status = ConnectionStatus.None

    private var mqttClient : MQTTClient?
    
    //
    private init() {
        
    }
    
    func connectFromSavedSettings() {
        let mqttSettings = MqttSettings.sharedInstance;
        
        if let host = mqttSettings.serverAddress {
            let port = mqttSettings.serverPort
            let username = mqttSettings.username
            let password = mqttSettings.password

            connect(host, port: port, username: username, password: password, cleanSession: true)
        }
    }
    
    func connect(host: String, port: Int, username: String?, password: String?, cleanSession: Bool) {
        // Configure MQTT connection
        let clientId = "Bluefruit_" + NSUUID().UUIDString
        let mqttConfig = MQTTConfig(clientId: clientId, host: host, port: Int32(port), keepAlive: MqttManager.defaultKeepAliveInterval)
        mqttConfig.cleanSession = cleanSession
        
        if (username != nil && password != nil) {
            mqttConfig.mqttAuthOpts = MQTTAuthOpts(username: username!, password: password!);
        }

        mqttConfig.onConnectCallback = { [ weak delegate = self.delegate,  unowned self /*, weak mqttClient = self.mqttClient*/ ] returnCode  in
            printLog("", funcName: (__FUNCTION__), logString: "MQTT connectedCallback \(returnCode.description)")

            self.status = returnCode == .Success ? ConnectionStatus.Connected : ConnectionStatus.Error
            let mqttSettings = MqttSettings.sharedInstance
            
            if (returnCode == .Success) {
                delegate?.onMqttConnected()
                
                let topic = mqttSettings.subscribeTopic
                let qos = mqttSettings.subscribeQos
                if (mqttSettings.isSubscribeEnabled && topic != nil) {
                    self.subscribe(topic!, qos: qos)
                }
            }
            else {
                // Connection error
                delegate?.onMqttError(returnCode.description);
                self.disconnect()                       // Stop reconnecting
                mqttSettings.isConnected = false        // Disable automatic connect on start

            }
        }

        mqttConfig.onDisconnectCallback = { [weak delegate = self.delegate] reasonCode  in
            printLog("", funcName: (__FUNCTION__), logString: "MQTT onDisconnectCallback")

            self.status = reasonCode == .Disconnect_Requested ? .Disconnected : .Error
            delegate?.onMqttDisconnected()
        }

        mqttConfig.onPublishCallback = { messageId in
            printLog("", funcName: (__FUNCTION__), logString: "published (mid=\(messageId))")
        }
        
        mqttConfig.onMessageCallback = { [weak delegate = self.delegate] mqttMessage in
            let payload = NSString(data: mqttMessage.payload, encoding: NSUTF8StringEncoding) as! String
            printLog("", funcName: (__FUNCTION__), logString: "MQTT Message received: payload=\(payload)")

            delegate?.onMqttMessageReceived(payload, topic: mqttMessage.topic)
        }
        
        // create new MQTT Connection
        printLog(self, funcName: (__FUNCTION__), logString: "MQTT connect")
        MqttSettings.sharedInstance.isConnected = true
        status = ConnectionStatus.Connecting
        mqttClient = MQTT.newConnection(mqttConfig)
    }

    func subscribe(topic: String, qos: MqttQos) {
        if let client = mqttClient {
             client.subscribe(topic, qos: Int32(qos.rawValue))
        }
    }
    
    func unsubscribe(topic: String) {
        mqttClient?.unsubscribe(topic)
    }
    
    func publish(message: String, topic: String, qos: MqttQos) {
        mqttClient?.publishString(message, topic: topic, qos: Int32(qos.rawValue), retain: false)
    }
    
    func disconnect() {
        if let client = mqttClient {
            status = .Disconnecting
            client.disconnect()
        }
        else {
            status = .Disconnected
        }
        
    }
}