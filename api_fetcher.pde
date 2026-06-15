import java.net.HttpURLConnection;
import java.net.URL;
import java.io.OutputStream;
import java.io.InputStreamReader;
import java.io.BufferedReader;

String apiKey = "";
String coimbraUrl = "https://newsapi.org/v2/everything?q=Coimbra&language=pt&sortBy=publishedAt&apiKey=";
String portugalUrl = "https://newsapi.org/v2/top-headlines?country=pt&pageSize=40&apiKey=";
String worldUrl = "https://newsapi.org/v2/top-headlines?language=en&pageSize=40&apiKey=";

String currentTitle = "A carregar dados locais...";
boolean newDataAvailable = false;

int totalApiResults = 0;
float newsImpactScore = 0;
String geminiApiKey = "";
int publishedHour = 0;
int publishedMinute = 0;
int publishedSecond = 0;

JSONArray cachedArticles = null;
int cachedTotalResults = 0;
int currentArticleIndex = 0;

void fetchPortugalData() {
  try {
    if (apiKey.equals("") || geminiApiKey.equals("")) {
      JSONObject keys = loadJSONObject("api_keys.json");
      if (keys != null) {
        apiKey = keys.getString("news_api_key");
        geminiApiKey = keys.getString("gemini_api_key");
        coimbraUrl += apiKey;
        portugalUrl += apiKey;
        worldUrl += apiKey;
      }
    }

    if (cachedArticles == null || cachedArticles.size() == 0) {
      JSONObject jsonCoimbra = loadJSONObject(coimbraUrl);
      JSONArray coimbraAll = null;
      if (jsonCoimbra != null && jsonCoimbra.getString("status").equals("ok")) {
        coimbraAll = jsonCoimbra.getJSONArray("articles");
        cachedArticles = filterRecent(coimbraAll, 24);
      }
      
      JSONArray portAll = null;
      if (cachedArticles == null || cachedArticles.size() == 0) {
        JSONObject jsonPort = loadJSONObject(portugalUrl);
        if (jsonPort != null && jsonPort.getString("status").equals("ok")) {
          portAll = jsonPort.getJSONArray("articles");
          cachedArticles = filterRecent(portAll, 24);
        }
      }
      
      JSONArray worldAll = null;
      if (cachedArticles == null || cachedArticles.size() == 0) {
        JSONObject jsonWorld = loadJSONObject(worldUrl);
        if (jsonWorld != null && jsonWorld.getString("status").equals("ok")) {
          worldAll = jsonWorld.getJSONArray("articles");
          cachedArticles = filterRecent(worldAll, 24);
        }
      }
      
      if (cachedArticles == null || cachedArticles.size() == 0) {
          if (coimbraAll != null && coimbraAll.size() > 0) cachedArticles = coimbraAll;
          else if (portAll != null && portAll.size() > 0) cachedArticles = portAll;
          else if (worldAll != null && worldAll.size() > 0) cachedArticles = worldAll;
      }
    }

    if (cachedArticles != null && cachedArticles.size() > 0) {
      int randomIndex = int(random(cachedArticles.size()));
      JSONObject selectedArticle = cachedArticles.getJSONObject(randomIndex);
      cachedArticles.remove(randomIndex);

      currentTitle = selectedArticle.getString("title");

      if (!geminiApiKey.equals("")) {
        newsImpactScore = fetchGeminiImpact(currentTitle, geminiApiKey);
        println("News Impact Score: " + newsImpactScore);
        if (newsImpactScore == 0)
          newsImpactScore = random(100);
      }

      if (posx.size() >= 200) {
        posx.clear();
        posy.clear();
        radiuses.clear();
        velx.clear();
        vely.clear();
        colors.clear();
        clearLeftScreen = true;
      }
      
      float hue = map(newsImpactScore, 0, 100, 0.5f, 0.833f);
      int trailColor = java.awt.Color.HSBtoRGB(hue, 1.0f, 1.0f);
      colors.append(trailColor);
      posx.append(random(leftW));
      posy.append(random(ledsH));
      radiuses.append(random(0.2, 1.5));
      
      float currentSpeed = map(newsImpactScore, 0, 100, 0, 3);
      float angle = random(TWO_PI);
      velx.append(cos(angle) * currentSpeed);
      vely.append(sin(angle) * currentSpeed);
      
      totalApiResults = posx.size();

      if (!selectedArticle.isNull("publishedAt")) {
        String publishedAt = selectedArticle.getString("publishedAt");
        if (publishedAt.length() >= 19) {
          publishedHour = int(publishedAt.substring(11, 13));
          publishedMinute = int(publishedAt.substring(14, 16));
          publishedSecond = int(publishedAt.substring(17, 19));
        }
      }
    } else {
      currentTitle = "Nenhuma notícia encontrada de momento. A tentar novamente...";
      newsImpactScore = 0;
      publishedHour = 0;
      publishedMinute = 0;
      publishedSecond = 0;
      colors = new IntList();
      posx = new FloatList();
      posy = new FloatList();
      radiuses = new FloatList();
      totalApiResults = 0;
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

int fetchGeminiImpact(String title, String key) {
  HttpURLConnection con = null;
  try {
    URL url = new URL("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=" + key);
    con = (HttpURLConnection) url.openConnection();
    con.setRequestMethod("POST");
    con.setRequestProperty("Content-Type", "application/json");
    con.setDoOutput(true);

    JSONObject body = new JSONObject();
    JSONArray contents = new JSONArray();
    JSONObject contentObj = new JSONObject();
    JSONArray parts = new JSONArray();
    JSONObject part = new JSONObject();

    String prompt = "Give me a single number from 1 to 100 representing the economic and social impact of this news title: \"" + title + "\". Only return the number, nothing else.";
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

    return int(text);
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
    return 0;
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
