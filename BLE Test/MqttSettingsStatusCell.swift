//
//  MqqtSettingsStatusCell.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 30/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

class MqttSettingsStatusCell: UITableViewCell {

    // UI
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var waitView: UIActivityIndicatorView!
    
    // Data
    var onClickAction : (() -> ())?
    
    @IBAction func onClickButton(sender: AnyObject) {
        self.onClickAction?()
    }
    
    /*
    override func awakeFromNib() {
        super.awakeFromNib()

    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
*/
}
