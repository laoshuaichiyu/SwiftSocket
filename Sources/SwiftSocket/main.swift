import Foundation
import Socket
import Dispatch

class LongSocket {
    
    static let bufferSize = 4096
    
    var connectSockets = [Int32: Socket]()
    var lisentSocket:Socket?
    var port:Int?
    var connectUsers = [Int32: String]()
    var connectUserNames = [String : [String : String]]()
    
    
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
                    
                    self.addNewConnectSocket(socket: newSocket)
                } while true
                
            } catch {
                print(error)
            }
        }
        dispatchMain()
    }
    
    func addNewConnectSocket(socket:Socket) {
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
                        let res = try? JSONSerialization.jsonObject(with: readData, options: .allowFragments)
                        guard let respone = res as? Dictionary<String, String> else {
                            break
                        }

                        var dt = respone
                        dt["host"] = socket.remoteHostname
                        dt["port"] = String(socket.remotePort)
                        self.connectUsers[socket.socketfd] = "exit"
                        self.connectUserNames.merge([dt["name"]! : dt], uniquingKeysWith: { (_, new) in new })
                        print(self.connectUserNames)
                        let data = try JSONSerialization.data(withJSONObject: self.connectUserNames, options: .prettyPrinted)

                        for (_, socket) in self.connectSockets {
                            let status = try socket.isReadableOrWritable()
                            if status.writable {
                                try socket.write(from: data)
                            }
                        }
                    } else {
                        print("close connect")
                        self.connectSockets.removeValue(forKey: socket.socketfd)
                        self.connectUsers.removeValue(forKey: socket.socketfd)
                        break
                    }
                } while true
            } catch {
                print("读取失败 - " + "\(error)")
            }
        }
    }
    func getSocketadd_in(address:Socket.Address) -> sockaddr_in? {
        var s:sockaddr_in?
        switch address {
        case let .ipv4(sockaddrin):
            s = sockaddrin
            break
            
        default: break
            
        }
        return s
    }
}

let server = LongSocket(port: 8080)

server.run()
