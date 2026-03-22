import java.net.*;
import java.io.*;

/**
 * P3DE Native OSC (Open Sound Control) Dispatcher
 * Zero-dependency UDP packet builder for sending 3D telemetry to TouchDesigner/Ableton
 */
class OSCMessage {
    String address;
    String types = ",";
    ByteArrayOutputStream dataStream = new ByteArrayOutputStream();
    DataOutputStream out = new DataOutputStream(dataStream);
    
    OSCMessage(String addr) {
        this.address = addr;
    }
    
    void addFloat(float v) {
        types += "f";
        try { out.writeFloat(v); } catch (Exception e) {}
    }
    
    void addString(String s) {
        types += "s";
        try { writePaddedString(out, s); } catch (Exception e) {}
    }
    
    void addInt(int v) {
        types += "i";
        try { out.writeInt(v); } catch (Exception e) {}
    }
    
    byte[] toByteArray() {
        ByteArrayOutputStream finalStream = new ByteArrayOutputStream();
        try {
            writePaddedString(finalStream, address);
            writePaddedString(finalStream, types);
            finalStream.write(dataStream.toByteArray());
        } catch(Exception e) {}
        return finalStream.toByteArray();
    }
    
    void writePaddedString(OutputStream os, String s) throws Exception {
        byte[] b = s.getBytes("UTF-8");
        os.write(b);
        int pad = 4 - (b.length % 4);
        for(int i=0; i<pad; i++) os.write(0);
    }
}

class OSCClient {
    DatagramSocket socket;
    InetAddress address;
    int port;
    boolean isConnected = false;
    
    void connect(String ip, int port) {
        this.port = port;
        try {
            this.address = InetAddress.getByName(ip);
            if (this.socket == null) this.socket = new DatagramSocket();
            this.isConnected = true;
            System.out.println("OSC Connected to " + ip + ":" + port);
        } catch (Exception e) {
            System.err.println("OSC Connection failed: " + e.getMessage());
            this.isConnected = false;
        }
    }
    
    void send(OSCMessage msg) {
        if (!isConnected || socket == null) return;
        byte[] data = msg.toByteArray();
        try {
            DatagramPacket packet = new DatagramPacket(data, data.length, address, port);
            socket.send(packet);
        } catch (Exception e) {}
    }
}
