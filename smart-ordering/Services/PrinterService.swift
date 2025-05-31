//
//  PrinterService.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/31.
//

import Foundation
import Network // For NWConnection

enum PrinterError: Error, LocalizedError {
    case connectionFailed(Error)
    case sendFailed(Error)
    case notConnected
    case configurationError(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let err): return "Printer connection failed: \(err.localizedDescription)"
        case .sendFailed(let err): return "Failed to send data to printer: \(err.localizedDescription)"
        case .notConnected: return "Not connected to the printer."
        case .configurationError(let msg): return "Printer configuration error: \(msg)"
        }
    }
}

class PrinterService {
    static let shared = PrinterService()
    private var connection: NWConnection?
    private let config = AppConfig.shared.kitchenPrinter // Get printer config

    func connectAndSendData(data: Data) async throws {
        guard !config.ipAddress.isEmpty, config.port > 0 else {
            throw PrinterError.configurationError("Printer IP Address or Port is not configured.")
        }
        
        let host = NWEndpoint.Host(config.ipAddress)
        guard let port = NWEndpoint.Port(rawValue: UInt16(config.port)) else {
            throw PrinterError.configurationError("Invalid printer port number.")
        }

        connection = NWConnection(host: host, port: port, using: .tcp)

        return try await withCheckedThrowingContinuation { continuation in
            connection?.stateUpdateHandler = { [weak self] newState in
                switch newState {
                case .ready:
                    print("Printer connected to: \(self?.config.ipAddress ?? ""):\(self?.config.port ?? 0)")
                    self?.send(data: data) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                        self?.disconnect() // Disconnect after sending
                    }
                case .failed(let error):
                    print("Printer connection failed: \(error.localizedDescription)")
                    continuation.resume(throwing: PrinterError.connectionFailed(error))
                    self?.connection = nil // Clear connection on failure
                case .cancelled:
                    print("Printer connection cancelled.")
                    // If cancellation wasn't intended as success, you might throw an error.
                    // For this flow, we assume cancellation happens after success/failure.
                    self?.connection = nil
                default:
                    break
                }
            }
            connection?.start(queue: .global(qos: .background))
        }
    }

    private func send(data: Data, completion: @escaping (PrinterError?) -> Void) {
        guard let connection = connection, connection.state == .ready else {
            completion(PrinterError.notConnected)
            return
        }

        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Failed to send data to printer: \(error.localizedDescription)")
                completion(PrinterError.sendFailed(error))
            } else {
                print("Data sent to printer successfully.")
                completion(nil)
            }
        })
    }

    private func disconnect() {
        connection?.cancel()
        connection = nil
        print("Printer connection disconnected.")
    }
}
