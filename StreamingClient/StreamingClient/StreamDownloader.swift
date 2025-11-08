//
//  StreamDownloader.swift
//  SplineAndSwiftUI
//
//  Created by rex on 11/8/25.
//

import Foundation

final class StreamDownloader: NSObject, URLSessionDataDelegate {
    private var expectedContentLength: Int64 = 0
    private var receivedDataLength: Int64 = 0
    private var outputFileHandle: FileHandle?
    private var destinationURL: URL?

    func startDownload(from url: URL) {
        // 準備儲存檔案的路徑
        let fileName = "downloaded_video.mp4"
        destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        FileManager.default.createFile(atPath: destinationURL!.path, contents: nil)
        outputFileHandle = try? FileHandle(forWritingTo: destinationURL!)

        // 建立 session
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: url)
        task.resume()

        print("🚀 開始下載：\(url.absoluteString)")
    }

    // 收到回應（可取得檔案大小）
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        expectedContentLength = response.expectedContentLength
        print("📏 檔案總大小：\(expectedContentLength) bytes")
        completionHandler(.allow)
    }

    // 收到資料區塊
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedDataLength += Int64(data.count)

        // 寫入檔案
        outputFileHandle?.write(data)

        // 顯示進度
        if expectedContentLength > 0 {
            let progress = Double(receivedDataLength) / Double(expectedContentLength)
            let percent = String(format: "%.2f", progress * 100)
            print("📦 已接收：\(receivedDataLength) / \(expectedContentLength) bytes (\(percent)%)")
        } else {
            print("📦 已接收：\(receivedDataLength) bytes")
        }
    }

    // 完成或錯誤
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        outputFileHandle?.closeFile()

        if let error = error {
            print("❌ 下載失敗：\(error.localizedDescription)")
        } else {
            print("✅ 下載完成！總接收：\(receivedDataLength) bytes")
            if let path = destinationURL?.path {
                print("💾 檔案已儲存至：\(path)")
            }
        }
    }
}
