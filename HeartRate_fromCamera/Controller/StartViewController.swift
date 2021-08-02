//
//  StartViewController.swift
//  HeartRate_fromCamera
//
//  Created by Naira Bassam on 31/07/2021.
//
import UIKit

class StartViewController: UIViewController {

    @IBOutlet weak var nabdaLabel: UILabel!
    @IBOutlet weak var careLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        nabdaLabel?.text = ""
        careLabel?.text = ""
        var nabdaIndex = 0.0
        var careIndex = 0.0
        let careText = "Because we care"
        let nabdaText = "Nabda"
        for letter in nabdaText {
            Timer.scheduledTimer(withTimeInterval: 0.4 * nabdaIndex, repeats: false) { (timer) in
                self.nabdaLabel.text?.append(letter)
            }
            nabdaIndex += 1
        }
       Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { (timer) in
            for letter in careText {
                Timer.scheduledTimer(withTimeInterval: 0.2 * careIndex, repeats: false) { (timer) in
                    self.careLabel.text?.append(letter)
                }
                careIndex += 1
            }
        
        }
        Timer.scheduledTimer(withTimeInterval: 5.5, repeats: false) { (timer) in
            self.performSegue(withIdentifier: "startIdentifier", sender: self)
        }
    }
   
}
