//
//  ResultViewController.swift
//  HeartRate_fromCamera
//
//  Created by Naira Bassam on 31/07/2021.
//

import UIKit

class ResultViewController: UIViewController {

    private var validFrameCounter = 0
    private var inputs: [CGFloat] = []
    private var hueFilter = Filter()
    private var pulseDetector = PulseDetector()
    private var measurementStartedFlag = false
    private var timer = Timer()
    
    let rppgController = ViewController()
    //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    weak var loopTimer: Timer?
    var secondRemaining = 6
    //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    var bufferImg: [UIImage] = []
    var pointContour: [[CGPoint]] = []
    var gArray: [CGFloat] = []
    var total: CGFloat = 0.0
    var redmean: CGFloat = 0
    var greenmean: CGFloat = 0
    var bluemean: CGFloat = 0
    //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    
    @IBOutlet weak var result: UILabel!
    @IBOutlet weak var resultType: UILabel!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    func runLoopTimer() {
        loopTimer?.invalidate()
        loopTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }
    @objc func updateTimer() {
        if secondRemaining > 0 {
            secondRemaining -= 1
            if secondRemaining == 0 {
                let averagergb = averageRGB(bufferImg)
                for i in 0..<averagergb.count{
                    redmean += averagergb[i][0]
                    greenmean += averagergb[i][1]
                    bluemean += averagergb[i][2]
                }
                //BandPassFilter
                let hsv = rgb2hsv((red: redmean, green: greenmean, blue: bluemean, alpha: 1.0))
                inputs.append(hsv.0)
                let filtered = hueFilter.processValue(value: Double(hsv.0))
                pulseDetector.addNewValue(newVal: filtered, atTime: CACurrentMediaTime())
                let average = self.pulseDetector.getAverage()
                let pulse = 60.0/average
                if pulse == -60 {
                    runLoopTimer()
                }else{
                    print(pulse)
                }
                result.text = "\(lroundf(Float(pulse))) BPM"
                
                //POS
                let l = Int(60 * 1.6)
                let range = averagergb.count
                let val: CGFloat = 0
                var H = Array(repeating: val, count: range)
                for t in 0..<(abs(range - l)){
                    // Step 1: Spatial averaging‏
                    let bc = Array<[CGFloat]>(averagergb[t..<abs(t+l-1)])
                    let C = transpose(bc)
                    //Step 2 : Temporal normalization
                    let meanColor = getMeanRow(C)
                    let diagMeanColor = Diagonal(meanColor)
                    let diagMeanColorInverse: [[CGFloat]] = diagMeanColor.reversed()
                    let Cn = multiply(diagMeanColorInverse, C)
                    //Step 3 : Projection
                    let projectionMatrix: [[CGFloat]] = [[0,1,-1],[-2,1,1]]
                    let S = multiply(projectionMatrix, Cn)
                    //Step 4: 2D signal to 1D signal

                    let stdVectorRes = standardDeviation(arr: S[0]) / standardDeviation(arr: S[1])
                    let std = [1.0,stdVectorRes]
                    var std2D: [[CGFloat]] = []
                    std2D.append(std)
                    let P2D = multiply(std2D, S)
                    let P = P2D[0]
                    //Step 5: OverLap-Adding
                    for i in 0..<P.count{
                        total = total + P[i]
                    }
                    let meanP = total/CGFloat(P.count)
                    let divP = div(standardDeviation(arr: P), (sub(meanP, P)))
                    H[t..<(t+l-1)] = H[t..<(t+l-1)] + divP
                }
                let h = appendH(H)
                let fft = FFT()
                let freq = fft.calculate(h, fps: 60)
                let powerSpec = fft.powerSpectra(h, 60)
                let first = freq.enumerated().filter({ $0.element > 0.9 }).map({ $0.offset })
                let last = freq.enumerated().filter({ $0.element < 1.8 }).map({ $0.offset })
                let firstIndex = first[0]
                let lastIndex = last[last.count-1]
                let rangeOfInterest = firstIndex..<(lastIndex)
                let maxValue = powerSpec.max()
                let maxIndex = powerSpec.firstIndex(of: maxValue!)
                let fMax = abs(freq[rangeOfInterest[maxIndex!]])
                let HR = fMax * 60
                result.text =  "\(lroundf(Float(HR))) BPM"
                spinner.stopAnimating()
                spinner.isHidden = true
                result.isHidden = false
                resultType.isHidden = false
                view.backgroundColor = #colorLiteral(red: 0.8590654731, green: 0.9489068389, blue: 0.9597404599, alpha: 1)
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        runLoopTimer()
        spinner.startAnimating()
        result.isHidden = true
        resultType.isHidden = true
    }
    func averageRGB(_ allImage: [UIImage]) -> [[CGFloat]]{
        var result: [[CGFloat]] = []
        let count = allImage.count
        for i in 0..<count{
            result.append(bufferImg[i].averageColor!)
        }
        return result
    }
    
    func Diagonal(_ array: [CGFloat]) -> [[CGFloat]] {
        let size = array.count
        let arrMatrix: [CGFloat] = Array(repeating: 0, count: size)
        var matrix: [[CGFloat]] = Array(repeating: arrMatrix, count: size)
        for i in 0..<size {
            matrix[i][i] = array[i]
        }
        return matrix
    }
    func transpose(_ matrix: Array<[CGFloat]>) -> Array<[CGFloat]> {
        let rowCount = matrix.count
        let colCount = matrix[0].count
        var transposed : Array<[CGFloat]> = Array(repeating: Array(repeating: 0.0, count: rowCount), count: colCount)
        for rowPos in 0..<matrix.count {
            for colPos in 0..<matrix[0].count {
                transposed[colPos][rowPos] = matrix[rowPos][colPos]
            }
        }
        return transposed
    }
    func getMeanRow(_ arr: [[CGFloat]]) -> [CGFloat]{
        let num = arr.count
        let sum = arr[0].count
        var total: CGFloat = 0.0
        var result: [CGFloat] = []
        for index in 0..<num{
            for i in 0..<sum{
                total += arr[index][i]
            }
            total /= 3.0
            result.append(total)
            total = 0.0
        }
        return result
    }
    func multiply(_ A: [[CGFloat]], _ B: [[CGFloat]]) -> [[CGFloat]] {
        let rowCount = A.count
        let colCount = B[0].count
        var product : [[CGFloat]] = Array(repeating: Array(repeating: 0.0, count: colCount), count: rowCount)
        for rowPos in 0..<rowCount {
            for colPos in 0..<colCount {
                for i in 0..<B.count {
                    product[rowPos][colPos] += A[rowPos][i] * B[i][colPos]
                }
            }
        }
        return product
    }
    func standardDeviation(arr : [CGFloat]) -> CGFloat
    {
        let length = CGFloat(arr.count)
        let avg = arr.reduce(0, {$0 + $1}) / length
        let sumOfSquaredAvgDiff = arr.map { pow($0 - avg, 2.0)}.reduce(0, {$0 + $1})
        return sqrt(sumOfSquaredAvgDiff / length)
    }
    func arrayToVector(_ array:[[CGFloat]]) -> [CGFloat]{
        var res: [CGFloat] = []
        for i in 0..<array.count{
            for x in 0..<array[0].count{
                res.append(array[i][x])
            }
        }
        return res
    }
    func mean(_ array:[CGFloat]) -> CGFloat{
        let num = array.count
        let arr: [CGFloat] = []
        var result: CGFloat = 0.0
        for x in 0..<arr.count{
            result += arr[x]
        }

        return result/CGFloat(num)
    }

    func sub(_ value: CGFloat, _ array:[CGFloat]) -> [CGFloat]{
        let num = array.count
        var result = array
        var valResult: CGFloat = 0.0
        for index in 0..<num{
            valResult = array[index] - value
            result[index] = valResult
        }
        return result
    }
    func div(_ value: CGFloat, _ array:[CGFloat]) -> [CGFloat]{
        let num = array.count
        var result = array
        var valResult: CGFloat = 0.0
        for index in 0..<num{
            valResult = array[index] / value
            result[index] = valResult
        }
        return result
    }
   
    func appendH(_ arr: [CGFloat]) -> [Double]{
        var h: [Double] = []
        for i in 0..<arr.count{
            h.append(Double(arr[i]))
        }
        return h
    }
    
}
extension UIImage {
    var averageColor: [CGFloat]? {
        var rgb: [CGFloat] = []
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        rgb.append(CGFloat(bitmap[0]) )
        rgb.append(CGFloat(bitmap[1]) )
        rgb.append(CGFloat(bitmap[2]) )
        return rgb
    }
}
