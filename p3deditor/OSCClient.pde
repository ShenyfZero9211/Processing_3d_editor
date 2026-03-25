/**
 * OSCClient.pde - P3DE Native OSC Dispatcher
 * 
 * Version: v0.4.9
 * Responsibilities:
 * - Implements a zero-dependency OSC (Open Sound Control) builder.
 * - Handles UDP packet construction for real-time 3D telemetry.
 * - Supports type tagging (i, f, s) and binary padding.
 * - Facilitates synchronization with TouchDesigner, Ableton Live, and Max/MSP.
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
    
    /**
     * [ALGORITHM] Bytecode Construction
     * Converts the structured address, type tags, and arguments into a standard 
     * OSC-compliant byte array. Each string and data block is padded to a 
     * 32-bit (4-byte) boundary as per the OSC 1.0 specification.
     */
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
