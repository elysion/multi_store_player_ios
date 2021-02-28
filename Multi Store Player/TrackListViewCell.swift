import Foundation
import UIKit

class TrackListViewCell: UITableViewCell {
    @IBOutlet weak var newLabel: UILabel!
    @IBOutlet weak var artistsLabel: UILabel!
    @IBOutlet weak var labelLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var openButton: UIButton!
    
    var trackIndex = -1
}
