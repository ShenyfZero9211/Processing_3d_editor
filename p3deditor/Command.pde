import java.util.Stack;

abstract class Command {
  abstract void execute();
  abstract void undo();
}

class UndoManager {
  Stack<Command> undoStack = new Stack<Command>();
  Stack<Command> redoStack = new Stack<Command>();
  int maxStack = 50;

  void push(Command cmd) {
    undoStack.push(cmd);
    redoStack.clear();
    if (undoStack.size() > maxStack) undoStack.remove(0);
    System.out.println("Command recorded. Undo stack size: " + undoStack.size());
  }

  void undo() {
    if (undoStack.isEmpty()) return;
    Command cmd = undoStack.pop();
    cmd.undo();
    redoStack.push(cmd);
  }

  void redo() {
    if (redoStack.isEmpty()) return;
    Command cmd = redoStack.pop();
    cmd.execute();
    undoStack.push(cmd);
  }
}

// 1. Transform Command (Position, Rotation, Scale)
class TransformCommand extends Command {
  ArrayList<Integer> ids;
  PVector[] oldPos, newPos;
  PVector[] oldRot, newRot;
  PVector[] oldScale, newScale;
  SceneManager scene;

  TransformCommand(SceneManager scene, ArrayList<Entity> entities, 
                   PVector[] oP, PVector[] nP, 
                   PVector[] oR, PVector[] nR, 
                   PVector[] oS, PVector[] nS) {
    this.scene = scene;
    this.ids = new ArrayList<Integer>();
    for (Entity e : entities) ids.add(e.id);
    this.oldPos = oP; this.newPos = nP;
    this.oldRot = oR; this.newRot = nR;
    this.oldScale = oS; this.newScale = nS;
  }

  void execute() { apply(newPos, newRot, newScale); }
  void undo() { apply(oldPos, oldRot, oldScale); }

  private void apply(PVector[] p, PVector[] r, PVector[] s) {
    for (int i=0; i<ids.size(); i++) {
       Entity e = scene.findEntityById(ids.get(i));
       if (e != null) {
         if (p != null) e.transform.position.set(p[i]);
         if (r != null) e.transform.rotation.set(r[i]);
         if (s != null) e.transform.scale.set(s[i]);
       }
    }
  }
}

// 2. Add Entity Command
class AddEntityCommand extends Command {
  ArrayList<Entity> added = new ArrayList<Entity>();
  SceneManager scene;
  
  AddEntityCommand(SceneManager scene, Entity root) {
    this.scene = scene;
    collectRecursive(root);
  }
  
  private void collectRecursive(Entity e) {
    added.add(e);
    for (Entity child : e.children) collectRecursive(child);
  }

  void execute() {
    for (Entity e : added) {
      if (!scene.entities.contains(e)) scene.entities.add(e);
    }
  }

  void undo() {
    for (Entity e : added) {
      scene.entities.remove(e);
      scene.selectedEntities.remove(e);
    }
  }
}

// 3. Delete Entity Command
class DeleteEntityCommand extends Command {
  ArrayList<Entity> deleted;
  ArrayList<Entity> parents;
  SceneManager scene;

  DeleteEntityCommand(SceneManager scene, ArrayList<Entity> entities) {
    this.scene = scene;
    this.deleted = new ArrayList<Entity>(entities);
    this.parents = new ArrayList<Entity>();
    for (Entity e : deleted) parents.add(e.parent);
  }

  void execute() {
    for (Entity e : deleted) {
      if (e.parent != null) e.parent.children.remove(e);
      scene.entities.remove(e);
      scene.selectedEntities.remove(e);
    }
  }

  void undo() {
    for (int i=0; i<deleted.size(); i++) {
      Entity e = deleted.get(i);
      Entity p = parents.get(i);
      if (!scene.entities.contains(e)) scene.entities.add(e);
      if (p != null && !p.children.contains(e)) p.addChildNoUpdate(e);
    }
  }
}

// 4. Reparent Command
class ReparentCommand extends Command {
  int entityId;
  int oldParentId, newParentId;
  SceneManager scene;

  ReparentCommand(SceneManager scene, Entity e, Entity oldP, Entity newP) {
    this.scene = scene;
    this.entityId = e.id;
    this.oldParentId = (oldP != null) ? oldP.id : -1;
    this.newParentId = (newP != null) ? newP.id : -1;
  }

  void execute() { apply(newParentId); }
  void undo() { apply(oldParentId); }

  private void apply(int pId) {
    Entity e = scene.findEntityById(entityId);
    Entity p = (pId == -1) ? null : scene.findEntityById(pId);
    if (e != null) e.setParent(p, true);
  }
}

// 5. Value/String Edit Command (Naming, Manual Fields)
class ValueEditCommand extends Command {
  int entityId;
  int type; // 1=Name, 2=PosX...
  String oldVal, newVal;
  SceneManager scene;

  ValueEditCommand(SceneManager scene, Entity e, int type, String oV, String nV) {
    this.scene = scene;
    this.entityId = e.id;
    this.type = type;
    this.oldVal = oV; this.newVal = nV;
  }

  void execute() { apply(newVal); }
  void undo() { apply(oldVal); }

  private void apply(String val) {
    Entity e = scene.findEntityById(entityId);
    if (e == null) return;
    try {
      if (type == 1) e.name = val;
      else if (type == 2) e.transform.position.x = Float.parseFloat(val);
      else if (type == 3) e.transform.position.y = Float.parseFloat(val);
      else if (type == 4) e.transform.position.z = Float.parseFloat(val);
      else if (type == 5) e.transform.rotation.x = radians(Float.parseFloat(val));
      else if (type == 6) e.transform.rotation.y = radians(Float.parseFloat(val));
      else if (type == 7) e.transform.rotation.z = radians(Float.parseFloat(val));
      else if (type == 8) e.transform.scale.x = Float.parseFloat(val);
      else if (type == 9) e.transform.scale.y = Float.parseFloat(val);
      else if (type == 10) e.transform.scale.z = Float.parseFloat(val);
    } catch(Exception ex) {}
  }
}
