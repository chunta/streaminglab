const express = require('express')
const fs = require('fs')
const path = require('path')

const app = express()
const port = 3000
const videoPath = path.join(__dirname, 'diablo.mp4')

app.get('/video', (req, res) => {
  const stat = fs.statSync(videoPath)
  const fileSize = stat.size
  const range = req.headers.range

  if (!range) {
    res.writeHead(200, {
      'Content-Length': fileSize,
      'Content-Type': 'video/mp4'
    })
    fs.createReadStream(videoPath).pipe(res)
  } else {
    const parts = range.replace(/bytes=/, '').split('-')
    const start = parseInt(parts[0], 10)
    const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1
    const chunkSize = (end - start) + 1
    console.log(`▶️ 傳送區塊 ${start}-${end} (${chunkSize} bytes)`)

    const file = fs.createReadStream(videoPath, { start, end })
    const headers = {
      'Content-Range': `bytes ${start}-${end}/${fileSize}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': chunkSize,
      'Content-Type': 'video/mp4'
    }

    res.writeHead(206, headers)
    file.pipe(res)
  }
})

app.listen(port, () => {
  console.log(`🚀 Video server running on http://localhost:${port}/video`)
})
