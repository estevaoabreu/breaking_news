import java.net.HttpURLConnection;
import java.net.URL;
import java.io.OutputStream;
import java.io.InputStreamReader;
import java.io.BufferedReader;

String apiKey = "";
String coimbraUrl = "https://newsapi.org/v2/everything?q=Coimbra&language=pt&sortBy=publishedAt&apiKey=";

String currentTitle = "A carregar dados locais...";
boolean newDataAvailable = false;

int totalApiResults = 0;
float newsImpactScore = 0;
String geminiApiKey = "";
int publishedHour = 0;
int publishedMinute = 0;
int publishedSecond = 0;

JSONArray cachedArticles = null;
JSONArray allFetchedArticles = null;
long lastFetchTime = 0;
int cachedTotalResults = 0;
int currentArticleIndex = 0;

float newBlobHue, newBlobTargetHue, newBlobPx, newBlobPy, newBlobRad, newBlobVx, newBlobVy, newBlobDeform, newBlobSpeed;
boolean spawnNewBlob = false;

void fetchPortugalData() {
  try {
    if (apiKey.equals("") || geminiApiKey.equals("")) {
      JSONObject keys = loadJSONObject("api_keys.json");
      if (keys != null) {
        apiKey = keys.getString("news_api_key");
        geminiApiKey = keys.getString("gemini_api_key");
        if (!coimbraUrl.endsWith(apiKey)) coimbraUrl += apiKey;
      }
    }

    boolean timeToFetch = (System.currentTimeMillis() - lastFetchTime) > (30 * 60 * 1000);

    if (cachedArticles == null || cachedArticles.size() == 0) {
      if (timeToFetch) {
        cachedArticles = new JSONArray();
        
        try {
          JSONObject jsonCoimbra = loadJSONObject(coimbraUrl);
          if (jsonCoimbra != null && !jsonCoimbra.isNull("status") && jsonCoimbra.getString("status").equals("ok")) {
            JSONArray coimbraAll = jsonCoimbra.getJSONArray("articles");
            JSONArray recentCoimbra = filterRecent(coimbraAll, 72); // 72 hours because NewsAPI free tier delays 'everything' endpoint by 24h
            for (int i = 0; i < recentCoimbra.size(); i++) cachedArticles.append(recentCoimbra.getJSONObject(i));
          }
        } catch (Exception e) { println("Coimbra fetch failed: " + e.getMessage()); }
        
        allFetchedArticles = new JSONArray();
        for (int i = 0; i < cachedArticles.size(); i++) {
          allFetchedArticles.append(cachedArticles.getJSONObject(i));
        }
        lastFetchTime = System.currentTimeMillis();
      } else {
        cachedArticles = new JSONArray();
        if (allFetchedArticles != null) {
          for (int i = 0; i < allFetchedArticles.size(); i++) {
            cachedArticles.append(allFetchedArticles.getJSONObject(i));
          }
        }
      }
    }

    if (cachedArticles != null && cachedArticles.size() > 0) {
      boolean foundValidArticle = false;
      JSONObject selectedArticle = null;
      int socialScore = 50;
      int economicScore = 50;
      
      while (!foundValidArticle && cachedArticles.size() > 0) {
        int randomIndex = int(random(cachedArticles.size()));
        selectedArticle = cachedArticles.getJSONObject(randomIndex);
        cachedArticles.remove(randomIndex);
  
        currentTitle = selectedArticle.getString("title");
  
        if (!geminiApiKey.equals("")) {
          int[] scores = fetchGeminiImpact(currentTitle, geminiApiKey);
          socialScore = scores[0];
          economicScore = scores[1];
          newsImpactScore = economicScore;
          println("Social Impact: " + socialScore + " | Economic Impact: " + economicScore);
        } else {
          socialScore = (int)random(100);
          economicScore = (int)random(100);
          newsImpactScore = economicScore;
        }
        
        if (economicScore >= 10 || abs(socialScore - 50) >= 20) {
          foundValidArticle = true;
        } else {
          println("Skipping article due to low impact. S:" + socialScore + " E:" + economicScore);
        }
      }

      if (foundValidArticle && selectedArticle != null) {
        newBlobHue = random(1.0f);
        newBlobTargetHue = map(socialScore, 0, 100, 0.0f, 0.33f);
        newBlobPx = random(leftW);
        newBlobPy = random(ledsH);
        newBlobSpeed = random(0.25f, 1.0f);
        newBlobRad = map(economicScore, 0, 100, 2.0f, 8.0f);
        
        float angle = random(TWO_PI);
        newBlobVx = cos(angle) * newBlobSpeed;
        newBlobVy = sin(angle) * newBlobSpeed;
        newBlobDeform = map(newsImpactScore, 0, 100, 0.0f, 0.8f);
        
        spawnNewBlob = true;
  
        if (!selectedArticle.isNull("publishedAt")) {
          String publishedAt = selectedArticle.getString("publishedAt");
          if (publishedAt.length() >= 19) {
            publishedHour = int(publishedAt.substring(11, 13));
            publishedMinute = int(publishedAt.substring(14, 16));
            publishedSecond = int(publishedAt.substring(17, 19));
          }
        }
      } else {
        currentTitle = "Nenhuma notícia relevante encontrada de momento. A tentar novamente...";
      }
    } else {
      currentTitle = "Nenhuma notícia encontrada de momento. A tentar novamente...";
    }
  }
  catch (Exception e) {
    currentTitle = "Erro na ligação ao servidor de notícias.";
    println("Fetch details failed: " + e.getMessage());
  }
  finally {
    newDataAvailable = true;
  }
}

int[] fetchGeminiImpact(String title, String key) {
  HttpURLConnection con = null;
  try {
    URL url = new URL("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=" + key);
    con = (HttpURLConnection) url.openConnection();
    con.setConnectTimeout(5000);
    con.setReadTimeout(5000);
    con.setRequestMethod("POST");
    con.setRequestProperty("Content-Type", "application/json");
    con.setDoOutput(true);

    JSONObject body = new JSONObject();
    JSONArray contents = new JSONArray();
    JSONObject contentObj = new JSONObject();
    JSONArray parts = new JSONArray();
    JSONObject part = new JSONObject();

    String prompt = "For this news title: \"" + title + "\", give me two numbers. 1) 'social': social impact from 0 (very negative) to 100 (very positive), where 50 is neutral. 2) 'economic': economic impact from 0 to 100. Reply ONLY in JSON format like {\"social\": 50, \"economic\": 20}.";
    part.setString("text", prompt);
    parts.append(part);
    contentObj.setJSONArray("parts", parts);
    contents.append(contentObj);
    body.setJSONArray("contents", contents);

    String jsonInputString = body.toString();

    try(OutputStream os = con.getOutputStream()) {
      byte[] input = jsonInputString.getBytes("utf-8");
      os.write(input, 0, input.length);
    }

    BufferedReader br = new BufferedReader(new InputStreamReader(con.getInputStream(), "utf-8"));
    StringBuilder response = new StringBuilder();
    String responseLine = null;
    while ((responseLine = br.readLine()) != null) {
      response.append(responseLine.trim());
    }

    JSONObject jsonResponse = parseJSONObject(response.toString());
    JSONArray cands = jsonResponse.getJSONArray("candidates");
    JSONObject firstCandidate = cands.getJSONObject(0);
    JSONObject content = firstCandidate.getJSONObject("content");
    JSONArray outParts = content.getJSONArray("parts");
    String text = outParts.getJSONObject(0).getString("text").trim();
    if (text.startsWith("```json")) text = text.substring(7, text.length() - 3).trim();
    else if (text.startsWith("```")) text = text.substring(3, text.length() - 3).trim();
    
    JSONObject res = parseJSONObject(text);
    return new int[]{res.getInt("social", 50), res.getInt("economic", 0)};
  }
  catch (Exception e) {
    println("Gemini fetch error: " + e.getMessage());
    if (con != null) {
      try {
        java.io.InputStream errorStream = con.getErrorStream();
        if (errorStream != null) {
          BufferedReader br = new BufferedReader(new InputStreamReader(errorStream, "utf-8"));
          StringBuilder response = new StringBuilder();
          String responseLine = null;
          while ((responseLine = br.readLine()) != null) {
            response.append(responseLine.trim());
          }
          println("Error body: " + response.toString());
        }
      }
      catch (Exception ex) {
      }
    }
    return new int[]{50, 0};
  }
}

JSONArray filterRecent(JSONArray articles, int hours) {
  if (articles == null) return new JSONArray();
  JSONArray recent = new JSONArray();
  long threshold = System.currentTimeMillis() - (hours * 60L * 60L * 1000L);
  java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss");
  sdf.setTimeZone(java.util.TimeZone.getTimeZone("UTC"));
  for (int i = 0; i < articles.size(); i++) {
    JSONObject art = articles.getJSONObject(i);
    if (!art.isNull("publishedAt")) {
      String pub = art.getString("publishedAt");
      if (pub.length() >= 19) {
        try {
          long t = sdf.parse(pub.substring(0, 19)).getTime();
          if (t >= threshold) recent.append(art);
        } catch (Exception e) {}
      }
    }
  }
  return recent;
}
