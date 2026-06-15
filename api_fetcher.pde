import java.net.HttpURLConnection;
import java.net.URL;
import java.io.OutputStream;
import java.io.InputStreamReader;
import java.io.BufferedReader;

// API Configuration
String apiKey = ""; 

String coimbraUrl = "";
String portugalUrl = "";

// Data holders
String currentTitle = "A carregar dados locais...";
boolean newDataAvailable = false;

int totalApiResults = 0;
int newsImpactScore = 0;
String geminiApiKey = "";
int publishedHour = 0;
int publishedMinute = 0;
int publishedSecond = 0;
IntList cores = new IntList();

// Asynchronous worker function
void fetchPortugalData() {
  try {
    if (apiKey.equals("") || geminiApiKey.equals("")) {
      JSONObject keys = loadJSONObject("api_keys.json");
      if (keys != null) {
        apiKey = keys.getString("news_api_key");
        geminiApiKey = keys.getString("gemini_api_key");
        coimbraUrl = "https://newsapi.org/v2/everything?q=Coimbra&language=pt&sortBy=publishedAt&apiKey=" + apiKey;
        portugalUrl = "https://newsapi.org/v2/top-headlines?country=pt&pageSize=40&apiKey=" + apiKey;
      }
    }
    
    // Strategy 1: Try local Coimbra query pool first
    JSONObject json = loadJSONObject(coimbraUrl);
    JSONArray articles = null;
    
    if (json != null && json.getString("status").equals("ok")) {
      if (!json.isNull("totalResults")) totalApiResults = json.getInt("totalResults");
      articles = json.getJSONArray("articles");
    }
    
    // Strategy 2: Fallback to general Portuguese national news if Coimbra is quiet
    if (articles == null || articles.size() == 0) {
      json = loadJSONObject(portugalUrl);
      if (json != null && json.getString("status").equals("ok")) {
        if (!json.isNull("totalResults")) totalApiResults = json.getInt("totalResults");
        articles = json.getJSONArray("articles");
      }
    }
      cores.clear();
      for(int i=0;i<totalApiResults;i++)
      cores.append(color(random(255),random(255),random(255)));
    
    // Parse individual item values
    if (articles != null && articles.size() > 0) {
      int randomIndex = int(random(articles.size()));
      JSONObject selectedArticle = articles.getJSONObject(randomIndex);
      
      currentTitle = selectedArticle.getString("title");
      
      // Remove publisher brand trailing strings if present to clean up layout
      if (currentTitle.contains(" - ")) {
         currentTitle = currentTitle.substring(0, currentTitle.lastIndexOf(" - "));
      }
      
      if (!geminiApiKey.equals("")) {
        newsImpactScore = fetchGeminiImpact(currentTitle, geminiApiKey);
        println("News Impact Score: " + newsImpactScore);
      }
      
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
      cores.clear();
    }
  } catch (Exception e) {
    currentTitle = "Erro na ligação ao servidor de notícias.";
    println("Fetch details failed: " + e.getMessage());
  } finally {
    newDataAvailable = true;
  }
}

int fetchGeminiImpact(String title, String key) {
  try {
    URL url = new URL("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" + key);
    HttpURLConnection con = (HttpURLConnection) url.openConnection();
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
  } catch (Exception e) {
    println("Gemini fetch error: " + e.getMessage());
    return 0; 
  }
}
