//
//  SVGAUtils.swift
//  FBSnapshotTestCase
//
//  Created by clovelu on 2020/7/1.
//

import Foundation
import CoreGraphics
import zlib
import CommonCrypto

extension Data {
    /**解压缩流大小**/
    private static let GZIP_STREAM_SIZE: Int32 = Int32(MemoryLayout<z_stream>.size)
    private static let GZIP_BUF_LENGTH:Int = 512
    private static let GZIP_NULL_DATA = Data()
    
    func zlibInflate() -> Data {
        guard self.count > 0  else { return self }
        
        var  stream = z_stream()
        stream.next_in = self.withUnsafeBytes { (bytes:UnsafePointer<Bytef>) in
            return UnsafeMutablePointer<Bytef>(mutating: bytes)
        }
        stream.avail_in = uInt(self.count)
        stream.total_out = 0
        
        var status: Int32 = inflateInit_(&stream, ZLIB_VERSION, Data.GZIP_STREAM_SIZE)
        guard status == Z_OK else { return self }
        
        var decompressed = Data(capacity: self.count * 2)
        var done = false
        while !done {
            if stream.total_out >= decompressed.count {
                decompressed.count += Data.GZIP_BUF_LENGTH
            }
        
            stream.next_out = decompressed.withUnsafeMutableBytes { (bytes:UnsafeMutablePointer<Bytef>)in
                return bytes.advanced(by: Int(stream.total_out))
            }
            stream.avail_out = uInt(uLong(decompressed.count) - stream.total_out)
            
            status = inflate(&stream, Z_SYNC_FLUSH)
            if status == Z_STREAM_END {
                done = true
            } else if status != Z_OK {
                break
            }
        }
        
        if inflateEnd(&stream) != Z_OK {
            return self
        }
        
        if done {
            decompressed.count = Int(stream.total_out)
            return decompressed
        }
        return self
    }
    
    func md5String() -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = withUnsafeBytes { ptr in
            guard let bytes = ptr.baseAddress?.bindMemory(to: Int8.self, capacity: 4) else {
                return
            }
            CC_MD5(bytes, CC_LONG(count), &digest)
        }
        var digestHex = ""
        for index in 0 ..< Int(CC_MD5_DIGEST_LENGTH) {
            digestHex += String(format: "%02x", digest[index])
        }
        return digestHex
    }
}
