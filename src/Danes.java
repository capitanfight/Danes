import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.util.*;

public class Listener {
    private static final int PORT = 9000;
    private static final int DISCOVERY_PORT = 9001;
    private static final String DISCOVERY_REQUEST = "DANES_DISCOVERY";
    private static final String RAID_DIR = System.getProperty("user.home") + "/.config/danes/raids";
    private static String serverName;

    public static void main(String[] args) {
        serverName = getServerName();
        System.out.println("Danes is conquering " + serverName);

        File raidDir = new File(RAID_DIR);
        if (!raidDir.exists()) {
            raidDir.mkdirs();
            System.out.println("Created raid targets at: " + RAID_DIR);
        }

        Thread discoveryThread = new Thread(() -> startDiscoveryService());
        discoveryThread.setDaemon(true);
        discoveryThread.start();

        try (ServerSocket serverSocket = new ServerSocket(PORT)) {
            System.out.println("Danes started on port " + PORT);
            System.out.println("Discovery service running on port " + DISCOVERY_PORT);
            System.out.println("Raid targets directory: " + raidDir.getAbsolutePath());
            System.out.println("Waiting for konungr to connect...");

            while (true) {
                try {
                    Socket clientSocket = serverSocket.accept();
                    System.out.println("The king has arrived: " + clientSocket.getInetAddress());
                    new Thread(() -> handleClient(clientSocket)).start();
                } catch (IOException e) {
                    System.err.println("Error accepting client: " + e.getMessage());
                }
            }
        } catch (IOException e) {
            System.err.println("Could not start Danes: " + e.getMessage());
            System.exit(1);
        }
    }

    private static String getServerName() {
        String name = System.getenv("USER");
        if (name == null || name.isEmpty()) name = System.getenv("USERNAME");
        if (name == null || name.isEmpty()) {
            String homeDir = System.getProperty("user.home");
            if (homeDir != null) name = new File(homeDir).getName();
        }
        if (name == null || name.isEmpty()) {
            try { name = InetAddress.getLocalHost().getHostName(); }
            catch (UnknownHostException e) { name = "Unknown"; }
        }
        return name;
    }

    private static void startDiscoveryService() {
        try (DatagramSocket socket = new DatagramSocket(DISCOVERY_PORT)) {
            socket.setBroadcast(true);
            System.out.println("Discovery service started on UDP port " + DISCOVERY_PORT);
            byte[] buffer = new byte[1024];
            while (true) {
                try {
                    DatagramPacket packet = new DatagramPacket(buffer, buffer.length);
                    socket.receive(packet);
                    String message = new String(packet.getData(), 0, packet.getLength());
                    if (message.trim().equals(DISCOVERY_REQUEST)) {
                        System.out.println("Discovery request received from " + packet.getAddress());
                        String localIP = getLocalIPAddress();
                        String response = localIP + ":" + PORT + ":" + serverName;
                        byte[] responseData = response.getBytes();
                        DatagramPacket responsePacket = new DatagramPacket(
                                responseData, responseData.length,
                                packet.getAddress(), packet.getPort());
                        socket.send(responsePacket);
                        System.out.println("Sent discovery response to " + packet.getAddress());
                    }
                } catch (IOException e) {
                    System.err.println("Discovery service error: " + e.getMessage());
                }
            }
        } catch (SocketException e) {
            System.err.println("Could not start discovery service: " + e.getMessage());
        }
    }

    private static String getLocalIPAddress() {
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            while (interfaces.hasMoreElements()) {
                NetworkInterface iface = interfaces.nextElement();
                if (iface.isLoopback() || !iface.isUp()) continue;
                Enumeration<InetAddress> addresses = iface.getInetAddresses();
                while (addresses.hasMoreElements()) {
                    InetAddress addr = addresses.nextElement();
                    if (addr instanceof Inet4Address && !addr.isLoopbackAddress()) {
                        return addr.getHostAddress();
                    }
                }
            }
        } catch (SocketException e) {
            System.err.println("Error getting local IP: " + e.getMessage());
        }
        try { return InetAddress.getLocalHost().getHostAddress(); }
        catch (UnknownHostException e) { return "127.0.0.1"; }
    }

    private static void handleClient(Socket clientSocket) {
        try {
            String command;
            while ((command = readLine(clientSocket)) != null) {
                command = command.trim();
                System.out.println("Received command: " + command);
                String[] parts = command.split(" ", 2);
                String action = parts[0].toUpperCase();
                try {
                    switch (action) {
                        default:
                            sendResponse(clientSocket, "ERROR: Unknown command: " + action);
                    }
                } catch (Exception e) {
                    sendResponse(clientSocket, "ERROR: " + e.getMessage());
                    e.printStackTrace();
                }
            }
        } catch (IOException e) {
            System.err.println("Client connection error: " + e.getMessage());
        } finally {
            try { clientSocket.close(); } catch (IOException e) { System.err.println("Error closing client socket: " + e.getMessage()); }
        }
    }

    private static String readLine(Socket socket) throws IOException {
        InputStream in = socket.getInputStream();
        StringBuilder sb = new StringBuilder();
        int c;
        while ((c = in.read()) != -1) {
            if (c == '\n') break;
            if (c != '\r') sb.append((char) c);
        }
        return sb.length() > 0 || c != -1 ? sb.toString() : null;
    }

    private static void sendResponse(Socket socket, String response) throws IOException {
        OutputStream out = socket.getOutputStream();
        out.write((response + "\n").getBytes());
        out.flush();
    }

    private static boolean runCommand(String[] cmd) {
        try {
            Process p = new ProcessBuilder(cmd)
                    .redirectErrorStream(true)
                    .start();
            // Drain output so the process doesn't block
            p.getInputStream().transferTo(OutputStream.nullOutputStream());
            int exit = p.waitFor();
            return exit == 0;
        } catch (Exception e) {
            return false;
        }
    }
}
