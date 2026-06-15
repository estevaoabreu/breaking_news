PGraphics pg;
PGraphics textMask;
PFont customFont;
PFont defaultFont;

int ledsW = 350;
int ledsH = 24;
int leftW = 275;
int rightW = 75;
int marqueeIterations = 1;
int blobLimit = 20;

boolean waitingForNews = false;
boolean clearLeftScreen = false;

int typeIndex = 0;
int typeTimer = 0;
int typeDelay = 10;
StringList visibleLines = new StringList();
boolean cursorOn = true;
int cursorBlinkRate = 15;
float rightPad = 5;
float lineGap = 2;
int articleDelayTimer = 0;
int timeBetweenArticles = 180;

FloatList hues = new FloatList();
FloatList targetHues = new FloatList();
StringList blobCategories = new StringList();
FloatList posx = new FloatList();
FloatList posy = new FloatList();
FloatList radiuses = new FloatList();
FloatList velx = new FloatList();
FloatList vely = new FloatList();
FloatList deformations = new FloatList();
FloatList baseSpeeds = new FloatList();

void settings() {
  float scaling = 10;
  while (ledsW * scaling > displayWidth) scaling--;
  size(int(ledsW * scaling), int(ledsH * scaling));
}

void setup() {
  pg = createGraphics(ledsW, ledsH);
  pg.noSmooth();
  pg.beginDraw();
  pg.background(12);
  pg.endDraw();
  
  textMask = createGraphics(ledsW, ledsH);
  customFont = createFont("font/DS-DIGI.TTF", 12);
  defaultFont = createFont("Arial", 9);
  
  thread("fetchPortugalData");
}

void draw() {
  if (newDataAvailable) {
    waitingForNews = false;
    newDataAvailable = false;
    typeIndex = 0;
    typeTimer = 0;
    visibleLines.clear();
    
    if (spawnNewBlob) {
      if (posx.size() >= blobLimit) {
        posx.clear(); posy.clear(); radiuses.clear();
        velx.clear(); vely.clear(); hues.clear(); targetHues.clear(); deformations.clear(); baseSpeeds.clear(); blobCategories.clear();
      }
      hues.append(newBlobHue);
      targetHues.append(newBlobTargetHue);
      blobCategories.append(newBlobCategory);
      posx.append(newBlobPx);
      posy.append(newBlobPy);
      radiuses.append(newBlobRad);
      velx.append(newBlobVx);
      vely.append(newBlobVy);
      deformations.append(newBlobDeform);
      baseSpeeds.append(newBlobSpeed);
      totalApiResults = posx.size();
      spawnNewBlob = false;
    }
  }

  pg.beginDraw();
  
  drawLeftScreen(pg, 0, 0, leftW, ledsH);
  drawRightScreen(pg, leftW, 0, rightW, ledsH);

  pg.endDraw();

  background(0);
  noStroke();
  float cellDim = 0.9 * (width / (float) pg.width);
  pg.loadPixels();
  for (int y = 0; y < pg.height; y++) {
    float cY = map(y + 0.5, 0, pg.height, 0, height);
    for (int x = 0; x < pg.width; x++) {
      float cX = map(x + 0.5, 0, pg.width, 0, width);
      fill(pg.pixels[x + y * pg.width]);
      circle(cX, cY, cellDim);
    }
  }
}

void drawLeftScreen(PGraphics pg, float x, float y, float w, float h) {
  pg.pushMatrix();
  pg.translate(x, y);


  pg.fill(12);
  pg.noStroke();
  pg.rect(0, 0, w, h);

  if (totalApiResults > 0) {

    FloatList accx = new FloatList();
    FloatList accy = new FloatList();
    for (int i=0; i<totalApiResults; i++) {
        accx.append(0); accy.append(0);
    }
    
    float separationDist = 20.0f; 
    float perceptionDist = 40.0f;
    
    for (int i=0; i<totalApiResults; i++) {
      float steerX = 0, steerY = 0;
      float alignX = 0, alignY = 0;
      float cohX = 0, cohY = 0;
      int countSep = 0, countAlign = 0, countCoh = 0;
      
      float pxi = posx.get(i); float pyi = posy.get(i);
      
      for (int j=0; j<totalApiResults; j++) {
        if (i == j) continue;
        float pxj = posx.get(j); float pyj = posy.get(j);
        float d = dist(pxi, pyi, pxj, pyj);
        
        if (d > 0 && d < separationDist) {
          float diffX = pxi - pxj;
          float diffY = pyi - pyj;
          diffX /= d; diffY /= d;
          steerX += diffX; steerY += diffY;
          countSep++;
        }
        if (d > 0 && d < perceptionDist && blobCategories.get(i).equals(blobCategories.get(j))) {
          alignX += velx.get(j); alignY += vely.get(j);
          countAlign++;
          cohX += pxj; cohY += pyj;
          countCoh++;
        }
      }
      
      float ax = 0, ay = 0;
      if (countSep > 0) {
        steerX /= countSep; steerY /= countSep;
        ax += steerX * 0.05f;
        ay += steerY * 0.05f;
      }
      if (countAlign > 0) {
        alignX /= countAlign; alignY /= countAlign;
        ax += (alignX - velx.get(i)) * 0.01f;
        ay += (alignY - vely.get(i)) * 0.01f;
      }
      if (countCoh > 0) {
        cohX /= countCoh; cohY /= countCoh;
        float desiredVX = cohX - pxi; float desiredVY = cohY - pyi;
        float speed = dist(0, 0, desiredVX, desiredVY);
        if (speed > 0) { desiredVX /= speed; desiredVY /= speed; }
        ax += (desiredVX - velx.get(i)) * 0.005f;
        ay += (desiredVY - vely.get(i)) * 0.005f;
      }
      
      accx.set(i, ax);
      accy.set(i, ay);
    }


    for (int i=0; i<totalApiResults; i++) {
      float vx = velx.get(i) + accx.get(i);
      float vy = vely.get(i) + accy.get(i);
      
      float speedMag = dist(0, 0, vx, vy);
      float mySpeed = baseSpeeds.get(i);
      if (speedMag > 0) {
        vx = (vx / speedMag) * mySpeed;
        vy = (vy / speedMag) * mySpeed;
      }
      velx.set(i, vx); vely.set(i, vy);
      
      float px = posx.get(i) + vx;
      float py = posy.get(i) + vy;
      float r = radiuses.get(i);
      
      if (px - r < 0) {
        px = r;
        velx.set(i, abs(velx.get(i)));
      } else if (px + r > w) {
        px = w - r;
        velx.set(i, -abs(velx.get(i)));
      }
      
      if (py - r < 0) {
        py = r;
        vely.set(i, abs(vely.get(i)));
      } else if (py + r > h) {
        py = h - r;
        vely.set(i, -abs(vely.get(i)));
      }
      
      posx.set(i, px);
      posy.set(i, py);
      
      float hVal = hues.get(i);
      float tHue = targetHues.get(i);
      
      float fluctuatingTarget = tHue + sin(millis() * 0.001f + i) * 0.05f;
      
      float diff = fluctuatingTarget - hVal;
      if (diff > 0.5f) diff -= 1.0f;
      if (diff < -0.5f) diff += 1.0f;
      
      hVal += diff * 0.02f;
      
      if (hVal < 0) hVal += 1.0f;
      if (hVal > 1.0f) hVal -= 1.0f;
      
      hues.set(i, hVal);
    }
    

    pg.loadPixels();
    for (int py = 0; py < h; py++) {
      for (int px = 0; px < w; px++) {
        float sum = 0;
        float rSum = 0;
        float gSum = 0;
        float bSum = 0;
        
        for (int i = 0; i < totalApiResults; i++) {
          float bx = posx.get(i);
          float by = posy.get(i);
          
          float pulse = 1.0f + 0.15f * sin(millis() * 0.005f + i);
          float radius = radiuses.get(i) * pulse * 3.0f;
          
          float dx = px - bx;
          float dy = py - by;
          
          float blobAngle = atan2(dy, dx);
          float time = millis() * 0.001f;
          float distFactor = 
              sin(blobAngle * 2.0f + time * 1.5f + i) * 0.5f +
              cos(blobAngle * 3.0f - time * 2.0f + i) * 0.3f +
              sin(blobAngle * 5.0f + time * 1.2f + i) * 0.2f;
              
          float distortion = 1.0f + deformations.get(i) * distFactor;
          float distSq = (dx*dx + dy*dy) * distortion;
          
          if (distSq > 0) {
            float influence = (radius * radius) / distSq;
            sum += influence;
            
            if (influence > 0.01f) {
              int c = java.awt.Color.HSBtoRGB(hues.get(i), 1.0f, 1.0f);
              float rCol = (c >> 16) & 0xFF;
              float gCol = (c >> 8) & 0xFF;
              float bCol = c & 0xFF;
              
              rSum += rCol * influence;
              gSum += gCol * influence;
              bSum += bCol * influence;
            }
          }
        }
        
        if (sum >= 1.0f) {
          int rCol = min(255, (int)(rSum / sum));
          int gCol = min(255, (int)(gSum / sum));
          int bCol = min(255, (int)(bSum / sum));
          
          int pIndex = (int)(px + x) + (int)(py + y) * pg.width;
          
          pg.pixels[pIndex] = color(rCol, gCol, bCol);
        }
      }
    }
    pg.updatePixels();
    
    }
    

  textMask.beginDraw();
  textMask.background(0);
  textMask.fill(255);
  textMask.textFont(customFont);
  textMask.textSize(20);
  textMask.textAlign(LEFT, CENTER);
  String timeStr = nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
  textMask.text(timeStr, x + 5, y + h / 2 - 2);
  textMask.endDraw();
  
  pg.loadPixels();
  textMask.loadPixels();
  for (int i = 0; i < textMask.pixels.length; i++) {
    int textIntensity = textMask.pixels[i] & 0xFF;
    if (textIntensity > 0) {
      int bgCol = pg.pixels[i];
      int bgR = (bgCol >> 16) & 0xFF;
      int bgG = (bgCol >> 8) & 0xFF;
      int bgB = bgCol & 0xFF;
      
      float alpha = textIntensity / 255.0f;
      int targetCol;
      if (bgR <= 15 && bgG <= 15 && bgB <= 15) {
        targetCol = 255;
      } else {
        targetCol = 0;
      }
      
      int outR = (int)(bgR * (1 - alpha) + targetCol * alpha);
      int outG = (int)(bgG * (1 - alpha) + targetCol * alpha);
      int outB = (int)(bgB * (1 - alpha) + targetCol * alpha);
      pg.pixels[i] = color(outR, outG, outB);
    }
  }
  pg.updatePixels();

  pg.popMatrix();
}

void drawRightScreen(PGraphics pg, float x, float y, float w, float h) {
  pg.pushMatrix();
  pg.translate(x, y);
  pg.clip(0, 0, w, h);
  pg.fill(12);
  pg.noStroke();
  pg.rect(0, 0, w, h);
  pg.textFont(defaultFont);
  pg.textSize(9);
  pg.textAlign(LEFT, TOP);

  int cCol = java.awt.Color.HSBtoRGB(newBlobTargetHue, 1.0f, 1.0f);
  pg.fill(color((cCol >> 16) & 0xFF, (cCol >> 8) & 0xFF, cCol & 0xFF));

  if (!waitingForNews && currentTitle != null) {
    if (typeIndex < currentTitle.length()) {
      typeTimer++;
      if (typeTimer >= typeDelay) {
        typeTimer = 0;
        char c = currentTitle.charAt(typeIndex);
        typeIndex++;

        if (c == '\n') {
          visibleLines.append("");
        } else {
          appendTypedChar(pg, Character.toUpperCase(c), w - rightPad * 2, h);
        }
      }
    }

    if (frameCount % cursorBlinkRate == 0) {
      cursorOn = !cursorOn;
    }

    float ascent = pg.textAscent();
    float descent = pg.textDescent();
    float lineH = ascent + descent + lineGap;
    float blockH = visibleLines.size() * lineH;
    float startY = blockH <= h ? (h - blockH) * 0.5f : h - blockH - 2;

    for (int i = 0; i < visibleLines.size(); i++) {
      float yy = startY + i * lineH;
      if (yy > h) continue;
      pg.text(visibleLines.get(i), rightPad, yy);
    }

    if (cursorOn && visibleLines.size() > 0) {
      int lastLine = visibleLines.size() - 1;
      String last = visibleLines.get(lastLine);
      float cursorX = rightPad + pg.textWidth(last);
      float cursorY = startY + lastLine * lineH;
      if (cursorY <= h - lineH) {
        pg.text("|", cursorX, cursorY);
      }
    }

    if (typeIndex >= currentTitle.length()) {
      waitingForNews = true;
      articleDelayTimer = timeBetweenArticles;
    }
  }
  
  if (waitingForNews && articleDelayTimer > 0) {
    articleDelayTimer--;
    if (articleDelayTimer == 0) {
      thread("fetchPortugalData");
    }
  }

  pg.noClip();
  pg.popMatrix();
}

void appendTypedChar(PGraphics pg, char c, float maxW, float maxH) {
  if (visibleLines.size() == 0) visibleLines.append("");
  int lastIdx = visibleLines.size() - 1;
  String line = visibleLines.get(lastIdx);
  if (pg.textWidth(line + c) > maxW) {
    if (c == ' ') {
      visibleLines.append("");
    } else {
      int lastSpace = line.lastIndexOf(' ');
      if (lastSpace > 0) {
        String wrappedWord = line.substring(lastSpace + 1) + c;
        visibleLines.set(lastIdx, line.substring(0, lastSpace));
        visibleLines.append(wrappedWord);
      } else {
        visibleLines.append(String.valueOf(c));
      }
    }
  } else {
    visibleLines.set(lastIdx, line + c);
  }
}
