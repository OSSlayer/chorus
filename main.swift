import Foundation
import Network

class AudioServer {
    let listener: NWListener
    var connections: [NWConnection] = []
    
    init() {
        do {
            listener = try NWListener(using: .tcp, on: 8081)
        } catch {
            fatalError("Failed to create listener: \(error)")
        }
    }
    
    func start() {
        listener.newConnectionHandler = { self.handleNewConnection($0) }
        listener.start(queue: .global())
        print("Server started on port \(listener.port!)")
    }
    
    func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] newState in
                switch newState {
                case .ready:
                    print("New client connected")
                case .failed(let error):
                    print("Client connection failed: \(error)")
                    self?.removeConnection(connection)
                case .cancelled:
                    print("Client disconnected")
                    self?.removeConnection(connection)
                default:
                    break
                }
            }
        
        connection.start(queue: .global())
        connections.append(connection)
    }
    
    func removeConnection(_ connection: NWConnection) {
        if let index = connections.firstIndex(where: { $0 === connection }) {
            connections.remove(at: index)
        }
    }
    
    func sendFile(_ filename: String?, playDate: TimeInterval) {
        let headerData = withUnsafeBytes(of: UInt64(playDate) ) { Data($0) }
        guard let filename = filename else {
            print("Sending stop command to all clients")
            for connection in server.connections { sendData(connection, headerData) }
            return
        }
        
        let fileManager = FileManager.default
        guard let downloadsPath = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            print("Could not locate downloads folder.") ; return
        }
        let fileUrl = downloadsPath.appendingPathComponent(filename)
        guard let fileData = try? Data(contentsOf: fileUrl) else {
            print("Failed to load file at \(fileUrl)") ; return
        }
        
        print("Sending \(filename) to \(connections.count) clients to play at \(Date(timeIntervalSince1970: playDate))")
        
        for connection in connections {
            sendData(connection, headerData)
            sendData(connection, fileData)
            sendData(connection, "end_file".data(using: .utf8)!)
        }
    }
    
    func sendData(_ connection: NWConnection, _ data: Data) {
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Error sending data: \(error)")
            }
        })
    }
}

// Usage
func clrScrn() { for _ in 0..<80 { print("\n") } }
func getInput() -> String { while true { if let input = readLine() { return input } } }

// Start Server
clrScrn()
let server = AudioServer()
server.start()
print("To play .wav files, enter the name of the file without the extension.\nEnter 'stop' to stop playback.\nPlayback will commence after a delay of 5 seconds.")

// Input
while true {
    let input = getInput()
    guard input.count > 0 else { continue }
    switch input {
    case "stop":
        server.sendFile(nil, playDate: 0)
    case "disconnect":
        for connection in server.connections { connection.cancel() }
    default:
        server.sendFile("\(input).wav", playDate: Date().timeIntervalSince1970 + 5)
    }
}

// Keep the server running
RunLoop.main.run()

