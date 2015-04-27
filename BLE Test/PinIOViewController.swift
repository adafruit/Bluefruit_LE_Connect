//
//  PinIOViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/6/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit

protocol PinIOViewControllerDelegate: HelpViewControllerDelegate {
    
    func sendData(newData: NSData)
    
}


class PinIOViewController : UIViewController, UITableViewDataSource, UITableViewDelegate, PinCellDelegate {
    
    private let SECTION_COUNT = 2
    private let HEADER_HEIGHT:CGFloat = 40.0
    private let ROW_HEIGHT_INPUT:CGFloat = 110.0
    private let ROW_HEIGHT_OUTPUT:CGFloat = 150.0
    private let MAX_CELL_COUNT = 20
    private let DIGITAL_PIN_SECTION = 0
    private let ANALOG_PIN_SECTION = 1
    private let FIRST_DIGITAL_PIN = 3
    private let LAST_DIGITAL_PIN = 8
    private let FIRST_ANALOG_PIN = 14
    private let LAST_ANALOG_PIN = 19
    private let PORT_COUNT = 3
    
    var delegate : PinIOViewControllerDelegate!
    @IBOutlet var pinTable : UITableView!
    @IBOutlet var headerLabel : UILabel!
    @IBOutlet var digitalPinCell : PinCell!
    @IBOutlet var helpViewController : HelpViewController!
    @IBOutlet var debugConsole : UITextView? = nil
    
    
    private let invalidCellPath = NSIndexPath(forItem: -1, inSection: -1)
    private var openCellPath : NSIndexPath = NSIndexPath(forItem: -1, inSection: -1)
    private var cells : [PinCell?] = []
    private var tableVisibleBounds : CGRect = CGRectZero
    private var tableOffScreenBounds : CGRect = CGRectZero
    private var pinTableAnimating : Bool = false
    private var readReportsSent : Bool =  false
    private var lastTime : Double = 0.0
    private var portMasks = [UInt8](count: 3, repeatedValue: 0)
    
    
    convenience init(delegate aDelegate:PinIOViewControllerDelegate){
        
        //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
        var nibName:NSString
        
        if IS_IPHONE {
            nibName = "PinIOViewController_iPhone"
        }
        else {
            nibName = "PinIOViewController_iPad"
        }
        
        self.init(nibName: nibName as String, bundle: NSBundle.mainBundle())
        
        self.delegate = aDelegate
        self.title = "Pin I/O"
        self.helpViewController?.title = "Pin I/O Help"
        readReportsSent = false
        
//        initializeCells()
        
//        helpViewController!.delegate = self.delegate
    }


    override func viewDidLoad() {

        super.viewDidLoad()

        //initialization

        helpViewController!.delegate = self.delegate

//        //initialize ivars
        initializeCells()
        
    }
    
    
    override func viewDidAppear(animated: Bool) {
        
        super.viewDidAppear(animated)
        
        //Request pin state reporting to begin if we haven't already
        if (readReportsSent == false){
            
            enableReadReports()
        }
    }
    
    
    //MARK: Connection & Initialization
    
    func didConnect(){
    
    //Respond to device connection
    
    }
    
    
    func initializeCells(){
        
        //Create & configure each table view cell
        
        cells = [PinCell?](count: MAX_CELL_COUNT, repeatedValue: nil)
        
        for (var i = 0; i<MAX_CELL_COUNT; i++) {
            
            let cellData = NSKeyedArchiver.archivedDataWithRootObject(digitalPinCell!)
            let cell:PinCell = NSKeyedUnarchiver.unarchiveObjectWithData(cellData) as! PinCell
            
            //Assign properties via tags
            cell.pinLabel = cell.viewWithTag(100) as! UILabel
            cell.modeLabel = cell.viewWithTag(101) as! UILabel
            cell.valueLabel = cell.viewWithTag(102) as! UILabel
            
            cell.toggleButton = cell.viewWithTag(103) as! UIButton
            cell.toggleButton.addTarget(self, action: Selector("cellButtonTapped:"), forControlEvents: UIControlEvents.TouchUpInside)
            //set tag to indicate digital pin number
            cell.toggleButton.tag = i
            
            cell.modeControl = cell.viewWithTag(104) as! UISegmentedControl
            cell.modeControl.addTarget(self, action: Selector("modeControlChanged:"), forControlEvents: UIControlEvents.ValueChanged)
            //set tag to indicate digital pin number
            cell.modeControl.tag = i
            
            cell.digitalControl = cell.viewWithTag(105) as! UISegmentedControl
            cell.digitalControl.addTarget(self, action: Selector("digitalControlChanged:"), forControlEvents: UIControlEvents.ValueChanged)
            //set tag to indicate digital pin number
            cell.digitalControl.tag = i
            
            cell.valueSlider = cell.viewWithTag(106) as! UISlider
            cell.valueSlider.addTarget(self, action: Selector("valueControlChanged:"), forControlEvents: UIControlEvents.ValueChanged)
            //set tag to indicate digital pin number
            cell.valueSlider.tag = i
            
            cell.delegate = self
            
            //PWM pins
            if ((i == 3) || (i == 5) || (i == 6)) {
                cell.isPWM = true
            }
            
            //Digital pins
            if (i >= FIRST_DIGITAL_PIN && i <= LAST_DIGITAL_PIN) {
                //setup digital pin
                cell.digitalPin = i
                cell.analogPin = -1;
                cell.pinLabel.text = "Pin \(cell.digitalPin)"
                cell.setDefaultsWithMode(PinMode.Input)
            }
                
            //Analog pins
            else if (i >= FIRST_ANALOG_PIN && i <= LAST_ANALOG_PIN){
                //setup analog pin
                cell.digitalPin = i
                cell.analogPin = i - FIRST_ANALOG_PIN
                cell.pinLabel.text = "Pin A\(cell.analogPin)"
                
                //starting as analog on pin 5
                if (cell.analogPin == 5) {
                    cell.setDefaultsWithMode(PinMode.Analog)
                }
                else{
                    cell.setDefaultsWithMode(PinMode.Input)
                }
            }
                
            else{
                //placeholder cell
                cell.digitalPin = -1
                cell.isAnalog = false
                cell.analogPin = -1
                
            }
            
            cells.append(cell)
            
        }
        
    }
    
    
    func enableReadReports(){
        
        //Set all pin read reports
        for cell in cells {
            if (cell?.digitalPin >= 0) { //placeholder cells are -1
                
                //set read reports enabled
                   setDigitalStateReportingForPin(UInt8(cell!.digitalPin), enabled: true)
                
            }
        }
        
        //set all pin modes active
        for cell in cells {
            if (cell?.digitalPin >= 0) { //placeholder cells are -1
                
                //set default pin mode
                modeControlChanged(cell!.modeControl)
                
            }
        }
        
    }
    
    
    func setDigitalStateReportingForPin(digitalPin:UInt8, enabled:Bool){
    
        //Enable input/output for a digital pin
        
        //port 0: digital pins 0-7
        //port 1: digital pins 8-15
        //port 2: digital pins 16-23
        
        //find port for pin
        var port:UInt8
        var pin:UInt8
        
        //find pin for port
        if (digitalPin <= 7){       //Port 0 (aka port D)
            port = 0
            pin = digitalPin
        }
    
        else if (digitalPin <= 15){ //Port 1 (aka port B)
            port = 1
            pin = digitalPin - 8
        }
    
        else{                       //Port 2 (aka port C)
            port = 2
            pin = digitalPin - 16
        }
    
        let data0:UInt8 = 0xd0 + port        //start port 0 digital reporting (0xd0 + port#)
        var data1:UInt8 = UInt8(portMasks[Int(port)])    //retrieve saved pin mask for port;
    
        if (enabled){
            data1 |= 1<<pin
        }
        else{
            data1 ^= 1<<pin
        }
    
        let bytes:[UInt8] = [data0, data1]
        let newData = NSData(bytes: bytes, length: 2)
    
        portMasks[Int(port)] = data1    //save new pin
    
        delegate!.sendData(newData)
    
    }
    
    
    func setDigitalStateReportingForPort(port:UInt8, enabled:Bool) {
        
        //Enable input/output for a digital pin
        
        //Enable by port
        var data0:UInt8 = 0xd0 + port  //start port 0 digital reporting (207 + port#)
        var data1:UInt8 = 0 //Enable
        if enabled {data1 = 1}
        
        let bytes:[UInt8] = [data0, data1]
        let newData = NSData(bytes: bytes, length: 2)
        delegate!.sendData(newData)
        
    }
    
    
    func setAnalogValueReportingforPin(pin:Int, enabled:Bool){
        
        //Enable analog read for a pin
        
        //Enable by pin
        var data0:UInt8 = 0xc0 + UInt8(pin)          //start analog reporting for pin (192 + pin#)
        var data1:UInt8 = 0    //Enable
        if enabled {data1 = 1}
        
        let bytes:[UInt8] = [data0, data1]
        
        let newData = NSData(bytes:bytes, length:2)
        
        delegate!.sendData(newData)
    }
    
    
    //MARK: Pin I/O Controls
    
    func digitalControlChanged(sender:UISegmentedControl){
    
    //Respond to user setting a digital pin high/low
    
    //Change relevant cell's value label
        let cell:PinCell? = pinCellForpin(Int(sender.tag))
        if cell == nil {
            return
        }
    
    let state = Int(sender.selectedSegmentIndex)
    
        cell?.setDigitalValue(state)
    
    //Send value change to BLEBB
        var pin = cell?.digitalPin
        writePinState(pinStateForInt(Int(state)), pin: UInt8(pin!))
        
//        printLog(self, "digitalControlChanged", "state = \(state) : pin = \(pin)")
    
    }
    
    
    func pinStateForInt(stateInt:Int) ->PinState{
        
        var state:PinState
        
        switch stateInt {
         
        case PinState.High.rawValue:
            state = PinState.High
            break
        case PinState.Low.rawValue:
            state = PinState.Low
            break
        default:
            state = PinState.High
            break
        }
        
        return state
    }
    
    
    func cellButtonTapped(sender:UIButton!){
        
        //Respond to user tapping a cell's top area to open/close cell
        
        //find relevant indexPath
        let indexPath:NSIndexPath = indexPathForSubview(sender)
        
        //if same button is tapped as previous, close the cell
        if (indexPath.compare(openCellPath) == NSComparisonResult.OrderedSame) {
            openCellPath = invalidCellPath
        }
        else {
            openCellPath = indexPath
        }
        
        updateTable()
        
        //if opening, scroll table until cell is visible after delay
        delay(0.25, { () -> () in
            self.scrollToIndexPath(indexPath)
            return
        })
        
    }
    
    
    func modeControlChanged(sender:UISegmentedControl){
        
        //Change relevant cell's mode
        
        let cell:PinCell? = pinCellForpin(sender.tag)!
        
        if (cell == nil) {
            return
        }
        
        let mode:PinMode = pinModeforControl(sender)
        let prevMode:PinMode = cell!.mode
        cell?.mode = mode
        
        //Write pin
        writePinMode(mode, pin: UInt8(cell!.digitalPin))
        
        //Update reporting for Analog pins
        if cell?.mode == PinMode.Analog {
            setAnalogValueReportingforPin(Int(cell!.analogPin), enabled: true)
        }
        else if prevMode == PinMode.Analog{
            setAnalogValueReportingforPin(Int(cell!.analogPin), enabled: false)
        }
        
    }
    
    
    @IBAction func toggleDebugConsole(sender:AnyObject) {
    
    //For debugging in development
    
        if debugConsole?.hidden == true{
            debugConsole?.hidden = false
        }
        else{
            debugConsole?.hidden = true
        }
    
    }
    
    
    func pinModeforControl(control:UISegmentedControl)->PinMode{
        
        //Convert segmented control selection to pin state
        
        let modeString:String = control.titleForSegmentAtIndex(control.selectedSegmentIndex)!
        
        var mode:PinMode = PinMode.Unknown
        
        if modeString == "Input" {
            mode = PinMode.Input
        }
        else if modeString == "Output" {
            mode = PinMode.Output
        }
        else if modeString == "Analog" {
            mode = PinMode.Analog
        }
        else if modeString == "PWM" {
            mode = PinMode.PWM
        }
        else if modeString == "Servo" {
            mode = PinMode.Servo
        }
        
        return mode
    }
    
    
    func valueControlChanged(sender:UISlider){
        
        //Respond to PWM value slider changes
        
        //Limit the amount of messages we send over BLE
        let time = CACurrentMediaTime() //Get current time
        if (time - lastTime < 0.05) {       //Bail if we're trying to send a value too soon
            return
        }
        
        lastTime = time
        
        //Find relevant cell based on slider control's tag
        let cell:PinCell = pinCellForpin(sender.tag)!
        
        //Bail if we have a redundant value
        if (cell.valueLabel.text?.toInt() == Int(sender.value)) {
            return
        }
        
        //Update the cell UI for the new value
        cell.setPwmValue(Int(sender.value))
        
        //Send the new value over BLE
        writePWMValue(UInt8(sender.value), pin: UInt8(cell.digitalPin))
        
    }
    
    
    //MARK: Outgoing Data
    
    func writePinState(newState: PinState, pin:UInt8){
        
        //Set an output pin's state
        
        var data0:UInt8  //Status
        var data1:UInt8  //LSB of bitmask
        var data2:UInt8  //MSB of bitmask
        
        //Status byte == 144 + port#
        var port:UInt8 = pin / 8
        
        data0 = 0x90 + port
        
        //Data1 == pin0State + 2*pin1State + 4*pin2State + 8*pin3State + 16*pin4State + 32*pin5State
        var pinIndex:UInt8 = pin - (port*8)
        var newMask = UInt8(newState.rawValue * Int(powf(2, Float(pinIndex))))
        
        if (port == 0) {
            portMasks[Int(port)] &= ~(1 << pinIndex) //prep the saved mask by zeroing this pin's corresponding bit
            newMask |= portMasks[Int(port)] //merge with saved port state
            portMasks[Int(port)] = newMask
            data1 = newMask<<1; data1 >>= 1  //remove MSB
            data2 = newMask >> 7 //use data1's MSB as data2's LSB
        }
            
        else {
            portMasks[Int(port)] &= ~(1 << pinIndex) //prep the saved mask by zeroing this pin's corresponding bit
            newMask |= portMasks[Int(port)] //merge with saved port state
            portMasks[Int(port)] = newMask
            data1 = newMask
            data2 = 0
            
            //Hack for firmata pin15 reporting bug?
            if (port == 1) {
                data2 = newMask>>7
                data1 &= ~(1<<7)
            }
        }
        
        let bytes:[UInt8] = [data0, data1, data2]
        let newData:NSData = NSData(bytes: bytes, length: 3)
        delegate!.sendData(newData)
        
        printLog(self, "setting pin states -->", "[\(binaryforByte(portMasks[0]))] [\(binaryforByte(portMasks[1]))] [\(binaryforByte(portMasks[2]))]")
        
    }
    
    
    func writePWMValue(value:UInt8, pin:UInt8) {
        
        //Set an PWM output pin's value
        
        var data0:UInt8  //Status
        var data1:UInt8  //LSB of bitmask
        var data2:UInt8  //MSB of bitmask
        
        //Analog (PWM) I/O message
        data0 = 0xe0 + pin;
        data1 = value & 0x7F;   //only 7 bottom bits
        data2 = value >> 7;     //top bit in second byte
        
        let bytes:[UInt8] = [data0, data1, data2]
        let newData:NSData = NSData(bytes: bytes,length: 3)
        
        delegate!.sendData(newData)
        
    }
    
    
    func writePinMode(newMode:PinMode, pin:UInt8) {
    
        //Set a pin's mode
    
        let data0:UInt8 = 0xf4        //Status byte == 244
        let data1:UInt8 = pin        //Pin#
        let data2:UInt8 = UInt8(newMode.rawValue)    //Mode
    
        let bytes:[UInt8] = [data0, data1, data2]
        let newData:NSData = NSData(bytes: bytes, length: 3)
    
        delegate!.sendData(newData)
    
    }
    
    
    //MARK: Incoming Data
    
    func receiveData(newData:NSData){
        
        //Respond to incoming data
        
        //Debugging in dev
        //    [self updateDebugConsoleWithData:newData];
        
        var data = [UInt8](count: 20, repeatedValue: 0)
        var buf = [UInt8](count: 512, repeatedValue: 0)  //static only works on classes & structs in swift
        var length:Int = 0                               //again, was static
        var dataLength:Int = newData.length
        
        newData.getBytes(&data, length: dataLength)
        
        if (dataLength < 20){
            
            memcpy(&buf, data, Int(dataLength))
            //        memcpy(&buf[length], data, dataLength)
            
            length += dataLength
            processInputData(buf, length: length)
            length = 0
        }
            
        else if (dataLength == 20){
            
            memcpy(&buf, data, 20)  //TODO: Check
            //    memcpy(&buf[length], data, 20);
            length += dataLength
            
            if (length >= 64){
                processInputData(buf, length: length)
                length = 0;
            }
        }
        
    }
    
    
    func processInputData(data:[UInt8], length:Int) {
        
        //Parse data we received
        
//        printLog(self, "processInputData", "data = \(data[0]) : length = \(length)")
        printLog(self, "received data", "data = \(data[0]) : length = \(length)")
        
        //each message is 3 bytes long
        for (var i = 0; i < length; i+=3){
            
            //Digital Reporting (per port)
            //Port 0
            if (data[i] == 0x90) {
                var pinStates = Int(data[i+1])
                pinStates |= Int(data[i+2]) << 7    //use LSB of third byte for pin7
                updateForPinStates(pinStates, port: 0)
                return
            }
                
                //Port 1
            else if (data[i] == 0x91){
                var pinStates = Int(data[i+1])
                pinStates |= Int(data[i+2]) << 7  //pins 14 & 15
                updateForPinStates(pinStates, port:1)
                return;
            }
                
                //Port 2
            else if (data[i] == 0x92) {
                var pinStates = Int(data[i+1])
                updateForPinStates(pinStates, port:2)
                return
            }
                
                //Analog Reporting (per pin)
            else if ((data[i] >= 0xe0) && (data[i] <= 0xe5)) {
                
                var pin = Int(data[i]) - 0xe0 + FIRST_ANALOG_PIN
                var val = Int(data[i+1]) + (Int(data[i+2])<<7);
                
                if (pin <= (cells.count-1)) {
                    let cell:PinCell? = pinCellForpin(Int(pin))
                    if (cell != nil) {
                        cell?.setAnalogValue(val)
                    }
                }
            }
        }
    }
    
    
    func updateDebugConsoleWithData(newData:NSData) {
    
        //For debugging in dev
    
        var hexString:NSString = newData.hexRepresentationWithSpaces(true)
    
        debugConsole!.text = debugConsole!.text.stringByAppendingString("\n \(hexString)")
    
        //scroll output to bottom
        if (debugConsole!.hidden == false) {
            let range = NSMakeRange(count(debugConsole!.text), 0)
            debugConsole!.scrollRangeToVisible(range)
            
            debugConsole!.scrollEnabled = false
            debugConsole!.scrollEnabled = true
        }
    
    }
    
    
    func updateForPinStates(pinStates:Int, port:Int) {
        
//        printLog(self, "updateForPinStates", "port = \(port) : pinStates = \(pinStates)")
        printLog(self, "getting pin states <--", "[\(binaryforByte(portMasks[0]))] [\(binaryforByte(portMasks[1]))] [\(binaryforByte(portMasks[2]))]")
        
        //Update pin table with new pin values received
        
        let offset = 8 * port
        
        //Iterate through all  pins
        for (var i:Int = 0; i <= 7; i++) {
            
            var state = pinStates
            let mask = 1 << i
            state = state & mask
            state = state >> i
            
            var cellIndex = i + Int(offset)
            
            if (cellIndex <= (cells.count-1)) {
                
                let cell = pinCellForpin(cellIndex)
                
                if (cell != nil) {
                    if (cell?.mode == PinMode.Input || cell?.mode == PinMode.Output){
                        cell?.setDigitalValue(state)
                    }
                    
                }
                
            }
        }
        
        //Save reference state mask
        portMasks[port] = UInt8(pinStates)
        
    }
    
    
    //MARK: Table view data source
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if (section == 0){
            return "Digital"
        }
            
        else{
            return "Analog"
        }
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var count = 0
        
        if section == DIGITAL_PIN_SECTION {
            count = LAST_DIGITAL_PIN - FIRST_DIGITAL_PIN + 1
        }
            
        else if (section == ANALOG_PIN_SECTION){
            count = LAST_ANALOG_PIN - FIRST_ANALOG_PIN + 1
        }
        
        return count;
        
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        //Return appropriate cell for a row index
        
        var cell:PinCell?
        
        //Set cell texts & type
        if indexPath.section == DIGITAL_PIN_SECTION{      //Digital Pins 2-7
            var pin = indexPath.row + FIRST_DIGITAL_PIN
            cell = self.pinCellForpin(pin)
            
        }
            
        else if indexPath.section == ANALOG_PIN_SECTION{  //Analog Pins A0-A5
            var pin = indexPath.row + FIRST_ANALOG_PIN
            cell = self.pinCellForpin(pin)
        }
        
        if (cell == nil){
            NSLog("-------> making a placeholder cell")
            cell = PinCell()
            var test: Void = UITextField.initialize()
        }
        
        return cell!
    }
    
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        
        //Return height appropriate for cell state - open/closed
        
        var height = pinTable?.rowHeight
        var cellIndex = 0
        
        if (indexPath.section == DIGITAL_PIN_SECTION) {
            cellIndex = indexPath.row + FIRST_DIGITAL_PIN
        }
        else if (indexPath.section == ANALOG_PIN_SECTION){
            cellIndex = indexPath.row + FIRST_ANALOG_PIN
        }
        
        if (cellIndex >= cells.count) {
            return 0
        }
        
        var cell:PinCell?
        cell = pinCellForpin(cellIndex)
        
        if (cell == nil) {
            return 0
        }
        
        //selected
        if (indexPath.compare(openCellPath) == NSComparisonResult.OrderedSame) {
            var mode = cell?.mode
            if (mode == PinMode.Input || mode == PinMode.Analog) {
                height = ROW_HEIGHT_INPUT
            }
            else {
                height = ROW_HEIGHT_OUTPUT
            }
            
            cell?.backgroundColor = UIColor.whiteColor()
        }
        
        //not selected
        else {
            cell?.backgroundColor = UIColor(white: 0.8, alpha: 1.0)
        }
        
        return height!
    }
    
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        //return height for title rows
        return HEADER_HEIGHT
        
    }
    
    
    func pinCellForpin(pin:Int) -> PinCell?{
        
        //Retrieve appropriate cell for a pin number
        
        if pin >= cells.count {
            return nil
        }
        
        var matchingCell:PinCell?
        
        for cell in cells {
            
            if cell == nil {
                continue
            }
            if Int(cell!.digitalPin) == pin {
                matchingCell = cell
                break
            }
        }
        
        return matchingCell
        
    }
    
    
    //MARK: Helper methods
    
    func indexPathForSubview(theView:UIView) ->NSIndexPath{
        
        //Find the indexpath for the cell which contains theView
        
        var indexPath: NSIndexPath?
        var counter = 0
        var limit = 20
        var aView:UIView? = theView
        
        while (indexPath == nil) {
            if (counter > limit) {
                break
            }
            if aView?.superview is UITableViewCell {
                let theCell = aView?.superview as! UITableViewCell
                indexPath = pinTable?.indexPathForCell(theCell)
            }
            else {
                aView = theView.superview
            }
            counter++;
        }
        
        return indexPath!
        
    }

    
    func updateTable(){
        
        //Animate row height changes for user selection
        
        pinTable!.beginUpdates()
        pinTable!.endUpdates()
        
    }
    
    
    func scrollToIndexPath(indexPath:NSIndexPath){
        
        //Scroll to a particular row on the table
        
        pinTable!.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.None, animated: true)
    }
    
    
    func cellModeUpdated(sender:AnyObject){
        
        //Respond to mode change for a cell
        
        self.updateTable()
        
    }
    
    
    func stringForPinMode(mode:PinMode)->NSString{
    
        var modeString: NSString
        
        switch mode {
        case PinMode.Input:
            modeString = "Input"
            break
        case PinMode.Output:
            modeString = "Output"
            break
        case PinMode.Analog:
            modeString = "Analog"
            break
        case PinMode.PWM:
            modeString = "PWM"
            break
        case PinMode.Servo:
            modeString = "Servo"
            break
        default:
            modeString = "NOT FOUND"
            break
        }
    
    return modeString
    
    }
    
}