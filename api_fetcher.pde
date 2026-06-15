import java.net.HttpURLConnection;
import java.net.URL;
import java.io.OutputStream;
import java.io.InputStreamReader;
import java.io.BufferedReader;

String apiKey = "";
String coimbraUrl = "https://api.worldnewsapi.com/search-news?source-countries=pt&api-key=";

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
String newBlobCategory = "Geral";
boolean spawnNewBlob = false;

void fetchPortugalData() {
  try {
    if (apiKey.equals("") || geminiApiKey.equals("")) {
      JSONObject keys = loadJSONObject("api_keys.json");
      if (keys != null) {
        apiKey = keys.getString("world_news_api_key");
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
          if (jsonCoimbra != null && !jsonCoimbra.isNull("news")) {
            JSONArray coimbraAll = jsonCoimbra.getJSONArray("news");
            JSONArray recentCoimbra = filterRecent(coimbraAll, 72);
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
        if (currentTitle != null) {
          currentTitle = currentTitle.replaceAll("&quot;", "\"")
                                     .replaceAll("&amp;", "&")
                                     .replaceAll("&#39;", "'")
                                     .replaceAll("&apos;", "'")
                                     .replaceAll("&lt;", "<")
                                     .replaceAll("&gt;", ">")
                                     .replaceAll("&nbsp;", " ")
                                     .replaceAll("[\u2018\u2019]", "'")
                                     .replaceAll("[\u201C\u201D]", "\"")
                                     .replaceAll("[\u2013\u2014]", "-");
          currentTitle = currentTitle.replaceAll("&#[0-9]+;", "");
          currentTitle = currentTitle.replaceAll("[^\\x20-\\x7E\\u00A0-\\u00FF]", "");
        }  
        if (!geminiApiKey.equals("")) {
          JSONObject scores = fetchGeminiImpact(currentTitle, geminiApiKey);
          socialScore = scores.getInt("social", 50);
          economicScore = scores.getInt("economic", 50);
          newBlobCategory = scores.getString("category", "Other");
          newsImpactScore = economicScore;
          println("Social Impact: " + socialScore + " | Economic Impact: " + economicScore + " | Category: " + newBlobCategory);
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
        textSocialHue = map(socialScore, 0, 100, 0.0f, 0.33f);
        newBlobHue = getCategoryHue(newBlobCategory);
        newBlobTargetHue = newBlobHue;
        newBlobPx = random(leftW);
        newBlobPy = random(ledsH);
        newBlobSpeed = random(0.05f, 0.2f);
        newBlobRad = map(economicScore, 0, 100, 4.0f, 12.0f);
        
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

JSONObject fetchGeminiImpact(String title, String key) {
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

    String prompt = "For this news title: \"" + title + "\", give me three values. 1) 'social': social impact from 0 (very negative) to 100 (very positive), where 50 is neutral. 2) 'economic': economic impact from 0 to 100. 3) 'category': the main category of the news. You MUST choose ONLY from this exact list: [Politics, Sports, Business, Technology, Entertainment, Health, Science, Lifestyle, Travel, Culture, Education, Environment, Other]. Reply ONLY in JSON format like {\"social\": 50, \"economic\": 20, \"category\": \"Politics\"}.";
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
    return res;
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
    JSONObject fallback = new JSONObject();
    fallback.setInt("social", 50);
    fallback.setInt("economic", 0);
    fallback.setString("category", "Other");
    return fallback;
  }
}

JSONArray filterRecent(JSONArray articles, int hours) {
  if (articles == null) return new JSONArray();
  JSONArray recent = new JSONArray();
  long threshold = System.currentTimeMillis() - (hours * 60L * 60L * 1000L);
  java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
  sdf.setTimeZone(java.util.TimeZone.getTimeZone("UTC"));
  for (int i = 0; i < articles.size(); i++) {
    JSONObject art = articles.getJSONObject(i);
    if (!art.isNull("publish_date")) {
      String pub = art.getString("publish_date");
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

float getCategoryHue(String cat) {
  cat = cat.trim().toLowerCase();
  if (cat.equals("politics")) return 0.00f; 
  if (cat.equals("sports")) return 0.08f; 
  if (cat.equals("business")) return 0.16f; 
  if (cat.equals("technology")) return 0.50f; 
  if (cat.equals("entertainment")) return 0.83f; 
  if (cat.equals("health")) return 0.33f; 
  if (cat.equals("science")) return 0.66f; 
  if (cat.equals("lifestyle")) return 0.91f; 
  if (cat.equals("travel")) return 0.12f; 
  if (cat.equals("culture")) return 0.75f; 
  if (cat.equals("education")) return 0.58f; 
  if (cat.equals("environment")) return 0.25f; 
  return 0.88f; 
}
