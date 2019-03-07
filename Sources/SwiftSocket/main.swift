import Foundation
import Socket
import Dispatch

class LongSocket {
    
    static let bufferSize = 4096
    
    var connectSockets = [Int32: Socket]()
    var lisentSocket:Socket?
    var port:Int?
    var connectUsers = [Int32: String]()
    var connectUserNames = [String]()
    
    
    init(port:Int) {
        self.port = port
    }
    
    func run() {
        let queue = DispatchQueue.global(qos: .userInteractive)
        queue.async { [unowned self] in
            do {
                self.lisentSocket = try Socket.create(family: .inet, type: .stream, proto: .tcp)
                guard let socket = self.lisentSocket else {
                    return
                }
                
                try socket.listen(on: self.port!)
                
                print("Socket start listen port \(self.port!)")
                
                repeat {
                    let newSocket = try socket.acceptClientConnection()
                    
                    print("new scoket in")
                    print("host:\(newSocket.remoteHostname)\nport:\(newSocket.remotePort)")
                    print(newSocket.signature!)
                    self.addNewConnectSocket(socket: newSocket)
                } while true
                
            } catch {
                print(error)
            }
        }
        dispatchMain()
    }
    
    func addNewConnectSocket(socket:Socket) {
        print(socket.socketfd)
//        self.connectSockets = [Int32: Socket]()
        DispatchQueue.main.sync { [unowned self, socket] in
            self.connectSockets[socket.socketfd] = socket
        }
        
        let queue = DispatchQueue.global(qos: .default)
        
        queue.async { [unowned self, socket] in
            var readData = Data(capacity: LongSocket.bufferSize)
            
            do {
                repeat {
                    
                    let byteRead = try socket.read(into: &readData)
                    if byteRead > 0 {
                        guard let respone = String(data: readData, encoding: .utf8) else {
                            break
                        }
                        if respone.hasPrefix("shutdown") {
                            DispatchQueue.main.sync {
                                exit(0)
                            }
                        }
                        print("add user \(respone)")
                        self.connectUsers[socket.socketfd] = respone
                        self.connectUserNames.append(respone)
                        let names:String = "\(socket.remotePort)"
                        var json = [String:String]()
                        json["port"] = "\(socket.remotePort)"
                        json["host"] = socket.remoteHostname
                        let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                        print(names)
                        for (_, socket) in self.connectSockets {
                            let status = try socket.isReadableOrWritable()
                            if status.writable {
                                try socket.write(from: data)
                            }
                        }
                        print("write")
                    } else {
                        print("close connect")
                        self.connectSockets.removeValue(forKey: socket.socketfd)
                        self.connectUsers.removeValue(forKey: socket.socketfd)
                        break
                    }
                } while true
            } catch {
                print(error)
            }
        }
    }
}

let server = LongSocket(port: 8080)

server.run()
