const std = @import("std");
const net = std.net;
const posix = std.posix;

pub fn main() !void {
    const address = try net.Address.parseIp("127.0.0.1", 8086);
    var tcpServer = try std.Thread.spawn(.{}, listenTcp, .{address});
    var udpServer = try std.Thread.spawn(.{}, listenUdp, .{address});
    tcpServer.join();
    udpServer.join();
}

fn listenTcp(address: net.Address) !void {
    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    const backlog = 128;
    try posix.listen(listener, backlog);
    std.debug.print("TCP server started on {}\n", .{address});

    var client_address: net.Address = undefined;
    var client_address_len: posix.socklen_t = @sizeOf(net.Address);
    while (true) {
        const socket = try posix.accept(listener, &client_address.any, &client_address_len, 0);
        errdefer posix.close(socket);
        std.debug.print("TCP {} connected\n", .{client_address});
        _ = try std.Thread.spawn(.{}, handleTcpConnection, .{ socket, client_address });
    }
}

fn handleTcpConnection(socket: posix.socket_t, client_address: net.Address) !void {
    defer posix.close(socket);
    var buf: [128]u8 = undefined;
    while (true) {
        const read_len = try posix.read(socket, &buf);
        if (read_len == 0) {
            std.debug.print("{} disconnected\n", .{client_address});
            break;
        }
        std.debug.print("TCP read {} bytes\n", .{read_len});

        const write_len = try posix.write(socket, buf[0..read_len]);
        std.debug.print("TCP write {} bytes\n", .{write_len});
    }
}

fn listenUdp(address: net.Address) !void {
    const tpe: u32 = posix.SOCK.DGRAM;
    const protocol = posix.IPPROTO.UDP;
    const socket = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(socket);

    try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(socket, &address.any, address.getOsSockLen());
    std.debug.print("UDP server started on {}\n", .{address});

    var buf: [128]u8 = undefined;
    while (true) {
        var client_addr: posix.sockaddr = undefined;
        var client_addr_len: posix.socklen_t = @sizeOf(posix.sockaddr);

        const read_len = try posix.recvfrom(socket, &buf, 0, &client_addr, &client_addr_len);
        std.debug.print("UDP read {} bytes\n", .{read_len});

        const sendto_len = try posix.sendto(socket, buf[0..read_len], 0, &client_addr, client_addr_len);
        std.debug.print("UDP write {} bytes\n", .{sendto_len});
    }
}
