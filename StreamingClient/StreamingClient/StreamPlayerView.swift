import SwiftUI
import AVKit
import Combine

struct StreamPlayerView: View {
    // 建立播放器 (AVPlayer)
    // AVPlayer 負責整個「媒體播放管線」：
    // - 根據 URL 建立串流連線
    // - 解析檔案格式與時間軸 (AVAsset)
    // - 控制緩衝、播放、暫停
    // - 與硬體解碼器 (VideoToolbox) 溝通並渲染畫面
    @State private var player: AVPlayer?
    
    // 播放緩衝進度（由 AVPlayerItem.loadedTimeRanges 提供）
    @State private var bufferProgress: Double = 0.0
    // 播放進度（由 AVPlayer 的播放時間提供）
    @State private var playProgress: Double = 0.0
    // 已下載的位元組數（從 AVPlayerItem.accessLog 計算）
    @State private var downloadedBytes: Double = 0.0
    // 用於 Combine 的 cancellables 集合
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack(spacing: 16) {
            if let player = player {
                // VideoPlayer 是 SwiftUI 封裝的 AVPlayerLayer
                // 會直接將 AVPlayer 的畫面輸出渲染到畫面上
                VideoPlayer(player: player)
                    .onAppear {
                        // 開始播放
                        player.play()
                        
                        // 啟動觀察：緩衝進度、播放時間、網路下載資訊
                        observeBuffer(for: player.currentItem)
                        observePlayTime(for: player)
                        observeNetwork(for: player.currentItem)
                    }
                    .frame(height: 280)
                    .cornerRadius(8)
                    .shadow(radius: 4)

                // ======== 自訂進度條 (UI) ========
                ZStack(alignment: .leading) {
                    GeometryReader { geo in
                        // 背景條
                        Rectangle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: geo.size.width)
                        // 緩衝進度條：AVPlayer 根據已下載的區段自動更新 loadedTimeRanges
                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: geo.size.width * bufferProgress)
                        // 播放進度條：由目前播放時間 / 總時長計算
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geo.size.width * playProgress)
                    }
                    .frame(height: 6)
                    .cornerRadius(3)
                }
                .frame(height: 6)
                .padding(.horizontal, 16)

                // ======== 狀態文字 ========
                Text("緩衝進度：\(Int(bufferProgress * 100))%")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.caption)
                Text("已下載：\(Int(downloadedBytes)) bytes")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption2)
            } else {
                // 若播放器尚未建立 → 顯示 Loading 狀態
                ProgressView("Loading stream...")
                    .onAppear {
                        setupPlayer()
                    }
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: Setup
    private func setupPlayer() {
        // 1️⃣ 建立 AVPlayer 並指向遠端串流 URL
        // AVPlayer 會自動：
        // - 建立 AVURLAsset（解析檔案結構與 metadata）
        // - 初始化緩衝機制
        // - 根據網路狀況自動調整請求區段 (Range Request)
        guard let url = URL(string: "http://104.236.10.8:3000/video") else { return }
        let player = AVPlayer(url: url)
        self.player = player
    }

    // MARK: Buffer observation
    private func observeBuffer(for item: AVPlayerItem?) {
        guard let item = item else { return }
        // 2️⃣ 觀察 loadedTimeRanges
        // AVPlayerItem.loadedTimeRanges 是 AVFoundation 自動維護的緩衝區資訊，
        // 當有新的資料段下載完成時會更新。
        item.publisher(for: \.loadedTimeRanges)
            .receive(on: DispatchQueue.main)
            .sink { ranges in
                guard let timeRange = ranges.first?.timeRangeValue else { return }
                let buffered = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration)
                let total = CMTimeGetSeconds(item.duration)
                // 更新緩衝進度百分比
                if total.isFinite && total > 0 {
                    bufferProgress = buffered / total
                }
            }
            .store(in: &cancellables)
    }

    // MARK: Play progress observation
    private func observePlayTime(for player: AVPlayer) {
        // 3️⃣ 觀察播放時間 (每 0.2 秒回報一次)
        // AVPlayer 會根據目前解碼到的幀時間更新 currentTime。
        // 我們可用這個時間與影片總時長比出播放進度。
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard let currentItem = player.currentItem else { return }
            let total = CMTimeGetSeconds(currentItem.duration)
            if total.isFinite && total > 0 {
                playProgress = CMTimeGetSeconds(time) / total
            }
        }
    }

    // MARK: Network Access Log 觀察
    private func observeNetwork(for item: AVPlayerItem?) {
        guard let item = item else { return }

        // 4️⃣ 使用 Notification 監聽 AVPlayerItemNewAccessLogEntry
        // AVPlayer 內部有「網路層紀錄器」，用來記錄下載速率、已傳輸 bytes。
        // 我們透過 accessLog 取出這些統計資料。
        NotificationCenter.default.publisher(for: .AVPlayerItemNewAccessLogEntry, object: item)
            .sink { _ in
                if let events = item.accessLog()?.events {
                    // numberOfBytesTransferred 為每段下載的總 bytes
                    let totalBytes = events.map { $0.numberOfBytesTransferred }.reduce(0, +)
                    downloadedBytes = Double(totalBytes)
                    print("📦 Total downloaded: \(totalBytes) bytes")
                }
            }
            .store(in: &cancellables)
    }
}
