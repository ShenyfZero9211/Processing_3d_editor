class Ray {
  PVector origin;
  PVector direction;
  Ray(PVector o, PVector d) { this.origin = o; this.direction = d; }
}

class Raycaster {
  Ray getPickRay(float mx, float my, float w, float h, PMatrix3D proj, PMatrix3D view) {
    // Combine Projection and View matrices and invert them together
    // This perfectly routes around intermediate W-division perspective losses!
    PMatrix3D pv = proj.get();
    pv.apply(view); // PV = Proj * View
    
    PMatrix3D invPV = pv.get();
    invPV.invert();
    
    // NDC coordinates (-1 to 1). OpenGL NDC has Y=+1 at the TOP.
    float nx = (2.0f * mx / w) - 1.0f;
    float ny = 1.0f - (2.0f * my / h); // Correctly flips Y so top of screen is +1
    
    // 1. Unproject near plane (z=-1)
    float[] nearNDC = {nx, ny, -1, 1};
    float[] nearWorld = new float[4];
    invPV.mult(nearNDC, nearWorld);
    if(nearWorld[3] != 0) {
      nearWorld[0] /= nearWorld[3]; nearWorld[1] /= nearWorld[3]; nearWorld[2] /= nearWorld[3];
    }
    
    // 2. Unproject far plane (z=1)
    float[] farNDC = {nx, ny, 1, 1};
    float[] farWorld = new float[4];
    invPV.mult(farNDC, farWorld);
    if(farWorld[3] != 0) {
      farWorld[0] /= farWorld[3]; farWorld[1] /= farWorld[3]; farWorld[2] /= farWorld[3];
    }
    
    PVector rayOrigin = new PVector(nearWorld[0], nearWorld[1], nearWorld[2]);
    PVector rayEnd = new PVector(farWorld[0], farWorld[1], farWorld[2]);
    PVector rayDir = PVector.sub(rayEnd, rayOrigin);
    rayDir.normalize();
    
    return new Ray(rayOrigin, rayDir);
  }
  
  float intersectPlane(Ray ray, PVector planeOrigin, PVector planeNormal) {
    float denom = PVector.dot(planeNormal, ray.direction);
    if (abs(denom) > 1e-6) {
      PVector p0l0 = PVector.sub(planeOrigin, ray.origin);
      float t = PVector.dot(p0l0, planeNormal) / denom;
      if (t >= 0) return t;
    }
    return -1;
  }
  
  float intersectAABB(Ray ray, PVector min, PVector max) {
    float t1 = (min.x - ray.origin.x) / ray.direction.x;
    float t2 = (max.x - ray.origin.x) / ray.direction.x;
    float t3 = (min.y - ray.origin.y) / ray.direction.y;
    float t4 = (max.y - ray.origin.y) / ray.direction.y;
    float t5 = (min.z - ray.origin.z) / ray.direction.z;
    float t6 = (max.z - ray.origin.z) / ray.direction.z;
    
    float tmin = max(max(min(t1,t2), min(t3,t4)), min(t5,t6));
    float tmax = min(min(max(t1,t2), max(t3,t4)), max(t5,t6));
    
    if (tmax < 0 || tmin > tmax) return -1;
    return tmin;
  }
  
  float intersectSphere(Ray ray, PVector center, float radius) {
    PVector oc = PVector.sub(ray.origin, center);
    float b = 2.0 * PVector.dot(oc, ray.direction);
    float c = PVector.dot(oc, oc) - radius*radius;
    float discriminant = b*b - 4*c;
    if (discriminant < 0) return -1;
    float t1 = (-b - sqrt(discriminant)) / 2.0;
    float t2 = (-b + sqrt(discriminant)) / 2.0;
    if (t1 > 0) return t1;
    if (t2 > 0) return t2;
    return -1;
  }
  
  float intersectEntity(Ray worldRay, Entity e) {
    // Use full world matrix for nested hierarchy picking
    PMatrix3D model = e.getWorldMatrix();
    
    PMatrix3D invModel = model.get();
    if (!invModel.invert()) return -1; // e.g. scale is 0
    
    // Transform ray origin
    float[] worldOrigin = {worldRay.origin.x, worldRay.origin.y, worldRay.origin.z, 1};
    float[] localOrigin = new float[4];
    invModel.mult(worldOrigin, localOrigin);
    
    // Transform ray end (origin + direction)
    PVector end = PVector.add(worldRay.origin, worldRay.direction);
    float[] worldEnd = {end.x, end.y, end.z, 1};
    float[] localEnd = new float[4];
    invModel.mult(worldEnd, localEnd);
    
    PVector localO = new PVector(localOrigin[0], localOrigin[1], localOrigin[2]);
    PVector localE = new PVector(localEnd[0], localEnd[1], localEnd[2]);
    PVector localD = PVector.sub(localE, localO);
    float lengthScale = localD.mag(); // ratio of world to local length
    if(lengthScale == 0) return -1;
    localD.normalize();
    
    Ray localRay = new Ray(localO, localD);
    
    float t = -1;
    if (e.type.equals("Cube")) {
      // P3D box(50) is centered, [-25, 25] on all axes
      t = intersectAABB(localRay, new PVector(-25, -25, -25), new PVector(25, 25, 25));
    } else if (e.type.equals("Sphere")) {
      // sphere(30) is centered with radius 30
      t = intersectSphere(localRay, new PVector(0,0,0), 30);
    } else if (e.type.equals("Plane")) {
      // Plane is drawn with box rotated PI/2 in X, making it lie on XZ naturally.
      // So the visual AABB is flat on Y axis (XZ slab)
      t = intersectAABB(localRay, new PVector(-50, -5, -50), new PVector(50, 5, 50));
    } else if (e.type.equals("PointLight")) {
      // Light sphere radius is 8 visually, but we use 12 for easier clicking
      t = intersectSphere(localRay, new PVector(0,0,0), 12);
    }
    
    if (t > 0) {
      return t / lengthScale; // Convert back to world space distance
    }
    return -1;
  }
}
