//
//  EditPictureViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/16/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SVProgressHUD
import CoreGraphics

class EditPictureViewController: UIViewController, UIScrollViewDelegate {
    
    var image: UIImage?
    var renderedImageView: UIImageView?

    @IBOutlet var blackView: UIView!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var blackViewHeight: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var overlapDiff: CGFloat = -1
        
        // Full view, not safe area
        blackViewHeight.constant = (70 / 736) * self.view.frame.height
        
        // Initialize scroll view properties
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.flashScrollIndicators()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 10
        scrollView.isScrollEnabled = true
        scrollView.delegate = self
        
        // Create image
        let imageView = UIImageView()
        if let chosenImage = image {
            let imageViewHeight = self.view.frame.width * (chosenImage.size.height / chosenImage.size.width)
            let yImagePos = self.view.center.y - (imageViewHeight / 2)
            var frame: CGRect = CGRect(x: 0, y: yImagePos - UIApplication.shared.statusBarFrame.height, width: self.view.frame.width, height: imageViewHeight)
            imageView.image = chosenImage
            
            // Adjust for image and black view overlap
            // If it's in portrait
            if chosenImage.size.height > chosenImage.size.width {
                // If overlapping
                if blackViewHeight.constant > yImagePos {
                    // Change position
                    overlapDiff = blackViewHeight.constant - yImagePos
                    frame = CGRect(x: 0, y: yImagePos - UIApplication.shared.statusBarFrame.height - overlapDiff, width: self.view.frame.width, height: imageViewHeight)
                }
            }
            
            imageView.frame = frame
            renderedImageView = imageView
            scrollView.addSubview(imageView)
        } else {
            SVProgressHUD.showError(withStatus: "There was a problem uploading your image. Please try again.")
            self.dismiss(animated: true, completion: nil)
        }
        
        let radius = (self.view.frame.width - Dimensions.getPoints(64)) / 2 // Radius of circle
        
        // Draw black circle outline with Core Graphics
        let diameter = radius * 2
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter+4, height: diameter+4))
        let img = renderer.image { (ctx) in
            ctx.cgContext.setFillColor(UIColor.clear.cgColor)
            ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
            ctx.cgContext.setLineWidth(2)
            let rectangle = CGRect(x: 2, y: 2, width: diameter, height: diameter)
            ctx.cgContext.addEllipse(in: rectangle)
            ctx.cgContext.drawPath(using: .stroke)
        }
        
        var circleFrame: CGRect = CGRect(x: Dimensions.getPoints(32), y: self.view.center.y - radius, width: diameter+4, height: diameter+4)
        if overlapDiff > 0 {
            circleFrame = CGRect(x: Dimensions.getPoints(32), y: self.view.center.y - radius - overlapDiff, width: diameter+4, height: diameter+4)
        }
        let imgview = UIImageView(frame: circleFrame)
        imgview.image = img
        self.view.addSubview(imgview)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UIScrollView Delegate Methods
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.renderedImageView
    }
    
    // MARK: IBOutlet Actions
    @IBAction func chooseImage(_ sender: Any) {
        print("submit image")
    }
    @IBAction func cancelEdit(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
