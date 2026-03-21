import java.io.*;
import java.util.*;

class LogEntry {
  String message;
  int type; // 0:Info, 1:Success, 2:Warn, 3:Error
  long timestamp;
  
  LogEntry(String m, int t) {
    message = m;
    type = t;
    timestamp = System.currentTimeMillis();
  }
}

class DebugConsole {
  ArrayList<LogEntry> logs = new ArrayList<LogEntry>();
  ArrayList<String> history = new ArrayList<String>();
  int historyIndex = -1;
  
  boolean active = false;
  String currentInput = "";
  float scrollOffset = 0;
  
  PrintWriter logWriter;
  CommandInterpreter interpreter;
  
  DebugConsole(CommandInterpreter interpreter) {
    this.interpreter = interpreter;
    try {
      // Create a unique timestamp for the file name
      String timestamp = p3deditor.this.year() + p3deditor.this.nf(p3deditor.this.month(), 2) + p3deditor.this.nf(p3deditor.this.day(), 2) + "-" + 
                         p3deditor.this.nf(p3deditor.this.hour(), 2) + p3deditor.this.nf(p3deditor.this.minute(), 2) + p3deditor.this.nf(p3deditor.this.second(), 2);
      String fileName = "editor_" + timestamp + ".log";
      
      // Dynamic Path Logic: Prioritize custom directory, fallback to local sketch
      String customPath = "D:\\projects\\Google_Antigravity\\p3deditor log";
      File dir = new File(customPath);
      File logFile;
      if (dir.exists() && dir.isDirectory()) {
        logFile = new File(dir, fileName);
      } else {
        logFile = new File(p3deditor.this.sketchPath(fileName));
      }
      
      logWriter = new PrintWriter(new FileWriter(logFile, false)); // No append needed for unique files
      addLog("--- Session Started (" + p3deditor.this.hour() + ":" + p3deditor.this.minute() + ":" + p3deditor.this.second() + ") ---", 0);
      addLog("Log File: " + logFile.getAbsolutePath(), 0);
    } catch (IOException e) {
      System.err.println("Failed to initialize log file: " + e.getMessage());
    }
  }
  
  void addLog(String msg, int type) {
    if (msg == null) return;
    
    // Split multi-line messages (like the alias list) into separate entries for clean rendering
    if (msg.contains("\n")) {
      String[] lines = msg.split("\n");
      for (String l : lines) {
        if (!l.trim().isEmpty()) logs.add(new LogEntry(l, type));
      }
    } else {
      logs.add(new LogEntry(msg, type));
    }

    if (logWriter != null) {
      String prefix = "[INFO] ";
      if (type == 1) prefix = "[SUCCESS] ";
      if (type == 2) prefix = "[WARN] ";
      if (type == 3) prefix = "[ERROR] ";
      logWriter.println(prefix + msg);
      logWriter.flush();
    }
  }
  
  void render() {
    if (!active) return;
    
    p3deditor.this.pushStyle();
    // 1. Semi-transparent glass overlay (top half)
    p3deditor.this.fill(20, 20, 25, 230);
    p3deditor.this.noStroke();
    p3deditor.this.rect(0, 0, p3deditor.this.width, p3deditor.this.height/2);
    p3deditor.this.stroke(100);
    p3deditor.this.line(0, p3deditor.this.height/2, p3deditor.this.width, p3deditor.this.height/2);
    
    // 2. Render Logs (Clipped to viewport)
    p3deditor.this.textAlign(p3deditor.this.LEFT, p3deditor.this.BOTTOM);
    p3deditor.this.textSize(13);
    
    float itemH = 18;
    float startY = p3deditor.this.height/2 - 45 + scrollOffset;
    
    p3deditor.this.clip(10, 10, p3deditor.this.width-20, p3deditor.this.height/2 - 50);
    float curY = startY;
    for (int i = logs.size()-1; i >= 0; i--) {
      LogEntry le = logs.get(i);
      if (le.type == 0) p3deditor.this.fill(200);                    // Info
      if (le.type == 1) p3deditor.this.fill(100, 200, 255);           // Success
      if (le.type == 2) p3deditor.this.fill(255, 200, 50);            // Warn
      if (le.type == 3) p3deditor.this.fill(255, 100, 100);           // Error
      
      p3deditor.this.text(le.message, 20, curY);
      curY -= itemH;
      if (curY < -20) break;
    }
    p3deditor.this.noClip();
    
    // 3. Input Line
    p3deditor.this.fill(40, 40, 50);
    p3deditor.this.rect(0, p3deditor.this.height/2 - 35, p3deditor.this.width, 35);
    p3deditor.this.fill(255);
    p3deditor.this.textAlign(p3deditor.this.LEFT, p3deditor.this.CENTER);
    String prompt = "> " + currentInput;
    if (p3deditor.this.millis() % 1000 < 500) prompt += "|";
    p3deditor.this.text(prompt, 15, p3deditor.this.height/2 - 17.5f);
    
    p3deditor.this.popStyle();
  }
  
  void handleKey(char key, int keyCode) {
    if (key == '`') {
      active = !active;
      return;
    }
    
    if (!active) return;
    
    if (key == p3deditor.this.ENTER || key == p3deditor.this.RETURN) {
      if (!currentInput.trim().isEmpty()) {
        addLog("> " + currentInput, 0); 
        history.add(currentInput);
        historyIndex = -1;
        
        String result = interpreter.execute(currentInput);
        if (result.startsWith("Error")) addLog(result, 3);
        else addLog(result, 1);
        
        currentInput = "";
        scrollOffset = 0;
      }
    } else if (key == p3deditor.this.BACKSPACE) {
      if (currentInput.length() > 0) currentInput = currentInput.substring(0, currentInput.length() - 1);
    } else if (keyCode == p3deditor.this.UP) {
      if (history.size() > 0) {
        if (historyIndex == -1) historyIndex = history.size() - 1;
        else historyIndex = p3deditor.this.max(0, historyIndex - 1);
        currentInput = history.get(historyIndex);
      }
    } else if (keyCode == p3deditor.this.DOWN) {
      if (historyIndex != -1) {
        historyIndex++;
        if (historyIndex >= history.size()) {
          historyIndex = -1;
          currentInput = "";
        } else {
          currentInput = history.get(historyIndex);
        }
      }
    } else if (key != p3deditor.this.CODED && key != p3deditor.this.ESC && key != p3deditor.this.TAB) {
      currentInput += key;
    }
  }

  void handleMouseWheel(float e) {
    if (!active) return;
    scrollOffset += e * 20;
    scrollOffset = p3deditor.this.max(0, scrollOffset);
  }
}
