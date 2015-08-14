//
//  MqttServiceEditValueCell.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 30/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

class MqttSettingsEditValueCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var valueTextField: UITextField?
    @IBOutlet weak var typeTextField: UITextField?
    
    func reset() {
        valueTextField?.text = nil
        valueTextField?.placeholder = nil
        valueTextField?.keyboardType = UIKeyboardType.Default;
        typeTextField?.text = nil
        typeTextField?.inputView = nil
        typeTextField?.inputAccessoryView = nil
    }
    
/*
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
*/
}
