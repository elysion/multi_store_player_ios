//
//  TrackListViewCell.swift
//  Multi Store Player
//
//  Created by Miko Kiiski on 05/01/2019.
//  Copyright © 2019 Miko Kiiski. All rights reserved.
//

import Foundation
import UIKit

class TrackListViewCell: UITableViewCell {
    @IBOutlet weak var newLabel: UILabel!
    @IBOutlet weak var artistsLabel: UILabel!
    @IBOutlet weak var labelLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var addToCartButton: UIButton!
    
    var trackIndex = -1
}
