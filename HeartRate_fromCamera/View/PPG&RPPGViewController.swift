//
//  PPG&RPPGViewController.swift
//  HeartRate_fromCamera
//
//  Created by Naira Bassam on 31/07/2021.
//
import UIKit

class PPG_RPPGViewController: UIViewController {

    @IBOutlet weak var PPG: UIButton!
    @IBOutlet weak var RPPG: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        style(RPPG)
        style(PPG)
    }
    

    func style (_ component: UIButton){
        component.layer.cornerRadius = component.frame.size.height / 2
        component.layer.shadowColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        component.layer.shadowOffset = CGSize(width: 0, height: 1.7)
        component.layer.shadowRadius = component.frame.size.height / 2
        component.layer.shadowOpacity = 0.19
    }
}
