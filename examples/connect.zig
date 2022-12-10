const std = @import("std");
const net = std.x.net;
const tcp = net.tcp;
const ws = @import("websocket");

const http_request_separator = "\r\n\r\n";
pub fn main() !void {
    const client = try tcpConnect();

    var write_buf: [4096]u8 = undefined;
    var read_buf: [4096]u8 = undefined;
    var hs = ws.Handshake.init("127.0.0.1:9001");

    _ = try client.write(try hs.request(&write_buf, "/runCase?case=7&agent=zig"), 0);
    var hwm: usize = 0;
    var eob: usize = 0;

    // handshake
    while (true) {
        const br = try client.read(read_buf[eob..], 0);
        if (br == 0) {
            return;
        }
        eob += br;
        const buf = read_buf[0..eob];
        var eor = std.mem.indexOf(u8, buf, http_request_separator) orelse 0;
        if (eor == 0) {
            continue;
        }
        eor += http_request_separator.len;
        const rsp_buf = read_buf[0..eor];
        if (!hs.isValidResponse(rsp_buf)) {
            try client.shutdown(.both);
            return;
        }
        hwm = eor;
        break;
    }

    // reading messages
    while (true) {
        const buf = read_buf[hwm..eob];
        if (buf.len > 0) {
            // std.debug.print("\n", .{});
            // for (buf) |b|
            //     std.debug.print("{x:0>2} ", .{b});

            var rsp = try ws.Frame.decode(buf);
            if (rsp[0] < 0) unreachable;
            var fr = rsp[1];
            var fe = fr.echo();
            const offset = fe.encode(&write_buf);
            _ = try client.write(write_buf[0..@intCast(usize, offset)], 0);
            // std.debug.print("\nrsp: ", .{});
            // for (write_buf[0..@intCast(usize, offset)]) |b|
            //     std.debug.print("{x:0>2} ", .{b});

            if (fr.opcode == .close) {
                try client.shutdown(.both);
                return;
            }

            hwm += @intCast(usize, rsp[0]);
            if (hwm < eob) {
                continue;
            }
        }
        hwm = 0;
        eob = 0;
        const br = try client.read(read_buf[eob..], 0);
        if (br == 0) {
            return;
        }
        eob = br;
    }
}

fn tcpConnect() !tcp.Client {
    const addr = net.ip.Address.initIPv4(try std.x.os.IPv4.parse("127.0.0.1"), 9001);
    const client = try tcp.Client.init(.ip, .{ .close_on_exec = true });
    try client.connect(addr);
    errdefer client.deinit();
    return client;
}

const upgrade_request = "GET ws://127.0.0.1:9001/runCase?case=3&agent=Chrome/105.0.0.0 HTTP/1.1\r\nHost: 127.0.0.1:9001\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nOrigin: http://example.com\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Protocol: chat, superchat\r\nSec-WebSocket-Version: 13\r\n\r\n";
