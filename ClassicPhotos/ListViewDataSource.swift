/// Copyright (c) 2019 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit

class ListViewDataSource: NSObject, UITableViewDataSource {
    
    private var photos: [PhotoRecord]
    var tableView = UITableView()
    let pendingOperations = PendingOperations()
    
    init(photos: [PhotoRecord], tableView: UITableView) {
        self.photos = photos
        self.tableView = tableView
        
        super.init()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return photos.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath)
        
                //1
                if cell.accessoryView == nil {
                    let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
                    cell.accessoryView = indicator
                }
                let indicator = cell.accessoryView as! UIActivityIndicatorView
        
                //2
                let photoDetails = photos[indexPath.row]
        
                //3
                cell.textLabel?.text = photoDetails.name
                cell.imageView?.image = photoDetails.image
        
                //4
                switch (photoDetails.state) {
                case .filtered:
                    indicator.stopAnimating()
                case .failed:
                    indicator.stopAnimating()
                    cell.textLabel?.text = "Failed to load"
                case .new, .downloaded:
                    indicator.startAnimating()
                    startOperations(for: photoDetails, at: indexPath)
                }
        
                if !tableView.isDragging && !tableView.isDecelerating {
                    startOperations(for: photoDetails, at: indexPath)
                }
        
                return cell
            }
    
            override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
                //1
                suspendAllOperations()
            }
    
            override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
                // 2
                if !decelerate {
                    loadImagesForOnscreenCells()
                    resumeAllOperations()
                }
            }
    
            override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
                // 3
                loadImagesForOnscreenCells()
                resumeAllOperations()
            }
    
            func suspendAllOperations() {
                pendingOperations.donwloadQueue.isSuspended = true
                pendingOperations.filterationQueue.isSuspended = true
            }
    
            func resumeAllOperations() {
                pendingOperations.donwloadQueue.isSuspended = false
                pendingOperations.filterationQueue.isSuspended = false
            }
    
            func loadImagesForOnscreenCells() {
                //1
                if let pathsArray = tableView.indexPathsForVisibleRows {
                    //2
                    var allPendingOperations = Set(pendingOperations.donwloadsInProgress.keys)
                    allPendingOperations.formUnion(pendingOperations.filterationInProgress.keys)
        
                    //3
                    var toBeCancelled = allPendingOperations
                    let visiblePaths = Set(pathsArray)
                    toBeCancelled.subtract(visiblePaths)
        
                    //4
                    var toBeStarted = visiblePaths
                    toBeStarted.subtract(allPendingOperations)
        
                    // 5
                    for indexPath in toBeCancelled {
                        if let pendingDownload = pendingOperations.donwloadsInProgress[indexPath] {
                            pendingDownload.cancel()
                        }
                        pendingOperations.donwloadsInProgress.removeValue(forKey: indexPath)
                        if let pendingFiltration = pendingOperations.filterationInProgress[indexPath] {
                            pendingFiltration.cancel()
                        }
                        pendingOperations.filterationInProgress.removeValue(forKey: indexPath)
                    }
        
                    // 6
                    for indexPath in toBeStarted {
                        let recordToProcess = photos[indexPath.row]
                        startOperations(for: recordToProcess, at: indexPath)
                    }
                }
            }
    
    func startOperations(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
        switch (photoRecord.state) {
        case .new:
            startDownload(for: photoRecord, at: indexPath)
        case .downloaded:
            startFiltration(for: photoRecord, at: indexPath)
        //            print("downloaded case switch")
        default:
            NSLog("do nothing")
        }
    }
    
    
    
    func startDownload(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
        //Checking if the operation exsists already, in that case we don't donwload it again.
        guard pendingOperations.donwloadsInProgress[indexPath] == nil else {
            return
        }
        
        // Download and set the img to photoRecord image.
        let downloader = ImageDownloader(photoRecord)
        
        
        downloader.completionBlock = {
            if downloader.isCancelled {
                return
            }
            
            DispatchQueue.main.async {
                // This occurs after the adding.
                //                self.tableView.reloadRows(at: [indexPath], with: .fade)  // Only enable if not using filter function.
                self.pendingOperations.donwloadsInProgress.removeValue(forKey: indexPath)
            }
        }
        
        // Adding the operation to the inProgressQueue
        // This occurs before the removal
        pendingOperations.donwloadsInProgress[indexPath] = downloader
        
        // Add the downloaded operation to the downloadQueue
        pendingOperations.donwloadQueue.addOperation(downloader)
    }
    
    func startFiltration(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
        guard pendingOperations.filterationInProgress[indexPath] == nil else {
            return
        }
        
        let filterer = ImageFiltration(photoRecord)
        filterer.completionBlock = {
            if filterer.isCancelled {
                return
            }
            
            DispatchQueue.main.async {
                // Update after filter has been added.
                self.pendingOperations.filterationInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
        
        
        // After the code has be ran, we add the downloader to the queue
        // and then when the operation is finished it will remove it from
        // the progress queue, but it will remain in the downloaded queue.
        pendingOperations.filterationInProgress[indexPath] = filterer
        pendingOperations.filterationQueue.addOperation(filterer)
    }
    }
        

    
    
    
    
    
//    // MARK: - Table view data source
//
//    override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
//        return photos.count
//    }
//
//    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath)
//
//        //1
//        if cell.accessoryView == nil {
//            let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
//            cell.accessoryView = indicator
//        }
//        let indicator = cell.accessoryView as! UIActivityIndicatorView
//
//        //2
//        let photoDetails = photos[indexPath.row]
//
//        //3
//        cell.textLabel?.text = photoDetails.name
//        cell.imageView?.image = photoDetails.image
//
//        //4
//        switch (photoDetails.state) {
//        case .filtered:
//            indicator.stopAnimating()
//        case .failed:
//            indicator.stopAnimating()
//            cell.textLabel?.text = "Failed to load"
//        case .new, .downloaded:
//            indicator.startAnimating()
//            startOperations(for: photoDetails, at: indexPath)
//        }
//
//        if !tableView.isDragging && !tableView.isDecelerating {
//            startOperations(for: photoDetails, at: indexPath)
//        }
//
//        return cell
//    }
//
//    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
//        //1
//        suspendAllOperations()
//    }
//
//    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
//        // 2
//        if !decelerate {
//            loadImagesForOnscreenCells()
//            resumeAllOperations()
//        }
//    }
//
//    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//        // 3
//        loadImagesForOnscreenCells()
//        resumeAllOperations()
//    }
//
//    func suspendAllOperations() {
//        pendingOperations.donwloadQueue.isSuspended = true
//        pendingOperations.filterationQueue.isSuspended = true
//    }
//
//    func resumeAllOperations() {
//        pendingOperations.donwloadQueue.isSuspended = false
//        pendingOperations.filterationQueue.isSuspended = false
//    }
//
//    func loadImagesForOnscreenCells() {
//        //1
//        if let pathsArray = tableView.indexPathsForVisibleRows {
//            //2
//            var allPendingOperations = Set(pendingOperations.donwloadsInProgress.keys)
//            allPendingOperations.formUnion(pendingOperations.filterationInProgress.keys)
//
//            //3
//            var toBeCancelled = allPendingOperations
//            let visiblePaths = Set(pathsArray)
//            toBeCancelled.subtract(visiblePaths)
//
//            //4
//            var toBeStarted = visiblePaths
//            toBeStarted.subtract(allPendingOperations)
//
//            // 5
//            for indexPath in toBeCancelled {
//                if let pendingDownload = pendingOperations.donwloadsInProgress[indexPath] {
//                    pendingDownload.cancel()
//                }
//                pendingOperations.donwloadsInProgress.removeValue(forKey: indexPath)
//                if let pendingFiltration = pendingOperations.filterationInProgress[indexPath] {
//                    pendingFiltration.cancel()
//                }
//                pendingOperations.filterationInProgress.removeValue(forKey: indexPath)
//            }
//
//            // 6
//            for indexPath in toBeStarted {
//                let recordToProcess = photos[indexPath.row]
//                startOperations(for: recordToProcess, at: indexPath)
//            }
//        }
//    }
}
