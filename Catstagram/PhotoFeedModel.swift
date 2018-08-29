/**
 * Copyright (c) 2018 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation

class PhotoFeedModel {
  private let numCommentsToShow = 3
  private let baseURL = "https://api.thecatapi.com/v1/"
  private let photosURI = "images/search?format=json&order=asc&size=small&has_breeds=false"
  
  // PLEASE REQUEST YOUR OWN API KEY AT https://thecatapi.com/docs.html
  private let apiKey = "c8b91376-bb43-4ebb-aee9-97d55005bb71"
  
  private var imageSize: CGSize
  private var photos = [PhotoModel]()
  private var ids: [String]
  private var urlString: String
  private var currentPage: UInt
  private var totalPages: UInt
  private var totalItems: UInt
  private var hasLoaded = false
  private var fetchPageInProgress: Bool
  private var refreshFeedInProgress: Bool
  private var task: URLSessionDataTask
  
  init(imageSize: CGSize) {
    self.imageSize = imageSize
    ids = [String]()
    currentPage = 0
    totalPages  = 0
    totalItems  = 0
    
    fetchPageInProgress   = false
    refreshFeedInProgress = false
    
    task = URLSessionDataTask()
    
    urlString = baseURL + photosURI
  }
  
  func numberOfItemsInFeed() -> Int {
    return photos.count
  }
  
  func object(at index: Int) -> PhotoModel {
    return photos[index]
  }
  
  func index(of photoModel: PhotoModel) -> Int {
    return photos.index(of: photoModel)!
  }
  
  func clearFeed() {
    photos = [PhotoModel]()
    ids = [String]()
    
    currentPage = 0
    fetchPageInProgress = false
    refreshFeedInProgress = false
    task.cancel()
    task = URLSessionDataTask()
  }
  
  func requestPage(with resultCount: UInt, completion: @escaping (([PhotoModel]) -> Void)) {
    guard !fetchPageInProgress else { return }
    
    fetchPageInProgress = true
    fetchPage(with: resultCount, replacingData: false, completion: completion)
  }
  
  func refreshFeed(with resultCount: UInt, completion: @escaping (([PhotoModel]) -> Void)) {
    guard !refreshFeedInProgress else { return }
    
    refreshFeedInProgress = true
    currentPage = 0
    fetchPage(with: resultCount, replacingData:true) { (results) in
      completion(results)
      self.refreshFeedInProgress = false
    }
  }
  
  //MARK: Helpers
  private func fetchPage(with resultCount: UInt, replacingData: Bool, completion: @escaping (([PhotoModel]) -> Void)) {
    if hasLoaded {
      guard currentPage != totalPages else {
        completion([])
        return
      }
    }
    
    DispatchQueue.global(qos: .default).async {
      var newPhotos = [PhotoModel]()
      var newIDs    = [String]()
      
      let nextPage = self.currentPage + 1
      //[NOTES]: Put this back to normal in the finished time profiler.  Not sure why "600" works but otherwise you need to choose 1-4
      let urlAdditions = "&page=\(nextPage)&limit=\(resultCount)"
      let url = URL(string: self.urlString + urlAdditions)
      var request = URLRequest(url: url!)
      request.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")
      let session = URLSession(configuration: .ephemeral)
      
      self.task = session.dataTask(with: request, completionHandler: { (data, response, error) in
        guard let data = data, let httpResponse = response as? HTTPURLResponse else { return }
        
        let json = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as! [[String: Any]]
        if let json = json {
          self.currentPage = UInt(httpResponse.allHeaderFields["pagination-page"] as! String) ?? 0
          self.totalItems = UInt(httpResponse.allHeaderFields["pagination-count"] as! String) ?? resultCount
          self.totalPages = UInt(ceil(Double(self.totalItems) / Double(resultCount)))

          for photoDictionary in json {
            let photo = PhotoModel(photoDictionary: photoDictionary)
            
            if replacingData || !self.ids.contains(photo.photoID!) {
              newPhotos.append(photo)
              newIDs.append(photo.photoID!)
            }
          }
        }
        DispatchQueue.main.async {
          if replacingData {
            self.photos = newPhotos
            self.ids = newIDs
          } else {
            self.photos.append(contentsOf: newPhotos)
            self.ids.append(contentsOf: newIDs)
          }
          completion(newPhotos)
          self.hasLoaded = true
          self.fetchPageInProgress = false
        }
      })
      self.task.resume()
    }
  }
}
