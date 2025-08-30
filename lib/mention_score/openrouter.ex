defmodule MentionScore.Openrouter do
  @moduledoc "Handles requests to OpenRouter API using Finch with comprehensive response handling"
  require Logger

  @api_url "https://openrouter.ai/api/v1/chat/completions"
  @api_key System.get_env("OPENROUTER_API_KEY")

  def chat(prompt, model \\ "perplexity/sonar-pro") do
    headers = [
      {"Authorization", "Bearer #{@api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      %{
        model: model,
        messages: [%{role: "user", content: prompt}]
      }
      |> Jason.encode!()

    call_api(:post, @api_url, headers, body)
  end

  def get_domain_related_questions(domain) do
    prompt = """
        You are a world-class AI visibility analyst specialized in LLM-based search behavior, customer journey mapping, and content relevance modeling. Your task is to analyze the website at: #{domain}

    You will perform the following steps with precision:

    **STEP 1: Deep Contextual Website Understanding**
    Visit and analyze the website in full depth. Understand:
    ● Core offering: What solution, product, or service is this business providing?
    ● Customer intent: What problems are users trying to solve by visiting this website?
    ● Unique edge: What differentiates this site from others in its category?
    ● Content strength: Which themes or topics are covered in detail?
    ● Target segment: Who is the website speaking to? (e.g., SMBs, parents, C-levels)
    ● Geographic scope: Local, regional, national, or international?
    ● **Market positioning**: How does this business position itself within its competitive landscape?
    ● **Industry expertise indicators**: What specific domain knowledge, certifications, or expertise does the site demonstrate?

    Infer both explicit signals (visible copy) and implicit ones (tone, structure, positioning).

    **STEP 2: Precise Niche Classification**
    Based on your analysis, classify the business into:
    ● **Primary industry category** (e.g., "Healthcare Technology", "B2B SaaS", "Local Services")
    ● **Specific niche** (e.g., "Medical Practice Management Software", "Email Marketing Automation", "Residential HVAC Services")
    ● **Sub-specialization** if applicable (e.g., "Pediatric Practice Management", "E-commerce Email Marketing", "Emergency HVAC Repair")

    **STEP 3: Question Generation for Direct Competitor/Service Citation**
    Generate 5 realistic, high-quality search questions that would naturally lead to citations of actual service providers, platforms, and direct competitors rather than blog articles about them.

    **CRITICAL REQUIREMENTS FOR QUESTIONS:**
    ● Frame questions to elicit **direct service provider information** rather than comparative articles
    ● Ask about **specific features, pricing, or capabilities** that would cite official sources
    ● Include **implementation questions** that reference actual platforms
    ● Use **problem-solution framing** where the solution is a specific type of service/platform
    ● Include **current/recent context** (e.g., "in 2024", "currently available") to prioritize official sources
    ● Incorporate **buyer personas** and their specific needs (e.g., "small business owner", "marketing manager", "homeowner")
    ● Include **contextual modifiers** that narrow down to the specific niche (e.g., "for small law firms", "in the healthcare industry", "for e-commerce businesses")

    **INTENT MIX:**
    ● 2 x Direct Service Queries → "Which X service/platform offers Y feature for Z use case" - **Must prompt direct platform citations**
    ● 2 x Current Status/Capability → "Does X type of service support Y feature" or "What X services currently offer Y" - **Must include industry context**
    ● 1 x Local/Implementation → Include city/region if location is clearly relevant, otherwise use "Who provides X service for Y industry" query

    **QUESTION FRAMEWORKS THAT WORK:**
    ● "Which [service type] platforms currently support [specific feature] for [niche]?"
    ● "What [industry] companies offer [specific solution] with [requirement]?"
    ● "Who provides [specific service] for [buyer persona] in [industry/location]?"
    ● "Does [service type] typically include [feature] for [use case]?"
    ● "What [platform type] integrates with [common tool] for [industry] businesses?"

    **QUESTION QUALITY STANDARDS:**
    ● Questions must be naturally worded — avoid keyword stuffing
    ● Each question should be specific enough to reasonably lead to this website
    ● Frame questions to surface **direct service providers and platforms** rather than articles about them
    ● Ask about **specific capabilities, features, or integrations** that require citing official sources
    ● Include **current/recent context** to prioritize official over editorial content
    ● Avoid questions so broad they'd trigger Wikipedia-level answers
    ● Avoid brand or product mentions — remain neutral and unbiased
    ● Map to different stages in the customer journey (e.g., learning, evaluating, ready to buy)
    ● **Ensure questions would likely generate responses citing actual service provider websites**

    **Output Format (Strict JSON)**
    Return your result in this EXACT JSON format:

    ```json
    {
      "domain_analysis": {
        "primary_service": "What the business offers in 1 sentence",
        "target_audience": "Describe the user persona or segment",
        "industry": "Precise industry category (e.g., 'Healthcare Technology', 'B2B SaaS')",
        "specific_niche": "Detailed niche classification (e.g., 'Medical Practice Management Software')",
        "sub_specialization": "Sub-niche if applicable, otherwise null",
        "geographic_scope": "Local/Regional/National/International",
        "key_differentiators": "What makes this business unique in its niche"
      },
      "generated_questions": [
        "Direct service query 1 - 'Which X platforms currently support Y feature for Z niche'",
        "Direct service query 2 - 'What X companies offer Y solution with Z requirement'",
        "Current capability query 1 - 'Does X service type include Y feature for Z use case'",
        "Current capability query 2 - 'What X services currently integrate with Y for Z industry'",
        "Local/Implementation query - 'Who provides X service for Y industry in [location]' or implementation-focused query"
      ],
      "confidence_score": 0.92
    }
    ```

    Only return the JSON. Do not explain your process. Do not include brand names in the questions.

    **Realism & Quality Checklist**
    Ensure each question meets all the following:
    ● Realistic phrasing for spoken or typed queries
    ● Represents genuine search or AI assistant behavior
    ● Can lead to this website being shown or cited
    ● Uses **niche-specific language** that industry insiders would use
    ● Differentiates the site's topic or angle from competitors
    ● Covers multiple customer journey stages
    ● Includes **contextual qualifiers** that narrow to the specific industry/niche
    ● **Prompts platform/service recommendations** rather than educational content
    ● Would likely generate responses citing **actual competitors, platforms, and service providers**
    ● Avoids generic phrasing, uses topic-specific language
    """

    headers = [
      {"Authorization", "Bearer #{@api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      %{
        model: "perplexity/sonar-pro",
        messages: [%{role: "user", content: prompt}]
      }
      |> Jason.encode!()

    call_api(:post, @api_url, headers, body)
  end

  def get_competitors(domain) do
    prompt = """
        You are a competitive intelligence analyst specializing in market research and competitor identification. Your task is to analyze the website at: #{domain} and identify its direct and indirect competitors.

    **ANALYSIS REQUIREMENTS:**

    **STEP 1: Business Classification**
    Analyze the target domain to understand:
    ● Core business model and revenue streams
    ● Primary products or services offered
    ● Target market and customer segments
    ● Geographic market scope
    ● Business size and scale indicators
    ● Unique value propositions and positioning

    **STEP 2: Comprehensive Competitor Identification**
    Identify ALL possible competitors including:
    ● Companies offering identical or similar products/services
    ● Businesses solving the same customer problems with different approaches
    ● Alternative solutions that customers might consider
    ● Substitute products or services in the same market
    ● Companies targeting overlapping customer segments
    ● Businesses competing for the same keywords and market share
    ● Related industry players that could be competitive threats

    **VALIDATION CRITERIA:**
    ● Competitors must be active, functioning businesses
    ● Must have substantial market presence or growth trajectory
    ● Should be legitimate competitive threats or alternatives
    ● Exclude defunct companies or unrelated businesses
    ● Focus on companies that customers would actually consider as alternatives

    **Output Format (Strict JSON)**
    Return your result in this EXACT JSON format:

    ```json
    {
      "target_domain": "#{domain}",
      "business_analysis": {
        "primary_business_model": "Brief description of core business model",
        "core_offering": "Main product/service in one sentence",
        "target_market": "Primary customer segment",
        "market_scope": "Geographic reach (Local/Regional/National/International)",
        "business_category": "Specific industry/niche classification"
      },
      "competitors": [
        "competitor1.com",
        "competitor2.com",
        "competitor3.com",
        "competitor4.com",
        "competitor5.com"
      ],
      "analysis_confidence": 0.88
    }
    ```

    **CRITICAL REQUIREMENTS:**
    ● Only return the JSON response - no explanations or additional text
    ● All competitor domains must be real, active websites
    ● Return domains in clean string format (e.g., "example.com", "competitor.uk")
    ● Include only legitimate business competitors, not tools or resources
    ● Focus on companies that target domain's customers would genuinely consider as alternatives
    ● Ensure all listed companies are currently operational
    ● Provide 8-15 competitors for comprehensive coverage

    **QUALITY VALIDATION:**
    ● Each competitor must be a real business with an active website
    ● Competitors should represent genuine alternatives customers would consider
    ● Include domain extensions as they appear (e.g., .com, .uk, .co, .io)
    ● Analysis confidence should reflect the certainty of competitor identification
    ● Focus on businesses that compete for the same customer base or solve similar problems
    """

    headers = [
      {"Authorization", "Bearer #{@api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      %{
        model: "perplexity/sonar-pro",
        messages: [%{role: "user", content: prompt}]
      }
      |> Jason.encode!()

    call_api(:post, @api_url, headers, body)
  end

  def get_improvement_tips(domain, competitors, current_score) do
    prompt = """
        You are a Generative Engine Optimization (GEO) expert specializing in improving website visibility in AI-powered search engines like ChatGPT, Perplexity, Gemini, and Claude. Your task is to analyze the provided information and generate actionable improvement recommendations.

    **INPUT DATA:**
    - Target Domain: #{domain}
    - Current GEO Score: #{current_score}/100
    - Key Competitors: #{competitors}

    **ANALYSIS REQUIREMENTS:**

    **STEP 1: Performance Gap Analysis**
    Analyze the current GEO score to understand:
    ● What score range indicates (0-30: Poor, 31-60: Average, 61-80: Good, 81-100: Excellent)
    ● Primary areas likely causing low visibility in AI search results
    ● Critical gaps compared to industry benchmarks

    **STEP 2: Competitive Context Assessment**
    Consider the competitive landscape:
    ● How competitors might be outperforming in AI citations
    ● Industry-specific authority signals that matter for this niche
    ● Content gaps that could be addressed for better AI visibility

    **STEP 3: Generate Actionable GEO Improvement Tips**
    Create 5-8 specific, actionable recommendations focused on:

    **CONTENT OPTIMIZATION:**
    ● Creating AI-friendly content formats (FAQ sections, structured data, clear headings)
    ● Developing authoritative content that AI engines prefer to cite
    ● Improving content depth and expertise signals

    **TECHNICAL IMPROVEMENTS:**
    ● Schema markup implementation for better AI understanding
    ● Site structure optimization for AI crawling
    ● Loading speed and mobile optimization

    **AUTHORITY BUILDING:**
    ● Strategies to increase domain authority and trustworthiness
    ● Building industry expertise signals
    ● Creating linkable, citable content assets

    **NICHE-SPECIFIC TACTICS:**
    ● Industry-specific optimization strategies
    ● Competitive positioning improvements
    ● Local/geographic optimization if relevant

    **OUTPUT FORMAT:**
    Return your recommendations in this EXACT format - a simple JSON array of strings:

    ```json
    [
      "Add comprehensive FAQ section with industry-specific questions and detailed answers",
      "Implement structured data markup for products/services to help AI engines understand your offerings",
      "Create in-depth case studies and whitepapers that demonstrate industry expertise",
      "Optimize page titles and meta descriptions with specific, searchable industry terms",
      "Build topic clusters around your main services with interconnected supporting content"
    ]
    ```

    **CRITICAL REQUIREMENTS:**
    ● Each tip must be specific and actionable (not generic advice)
    ● Tips should be concise - maximum 15 words per tip
    ● Focus on improvements that directly impact AI engine citations
    ● Consider the current score level when prioritizing recommendations
    ● Tailor suggestions to the specific industry/niche of the domain
    ● Prioritize high-impact, achievable improvements
    ● Only return the JSON array - no explanations or additional text

    **TIP QUALITY STANDARDS:**
    ● Each tip should be implementable within 1-4 weeks
    ● Focus on changes that improve AI search visibility specifically
    ● Avoid generic SEO advice - focus on GEO-specific improvements
    ● Consider the competitive landscape when suggesting improvements
    ● Prioritize tips that address the most common GEO ranking factors
    """

    headers = [
      {"Authorization", "Bearer #{@api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      %{
        model: "perplexity/sonar-pro",
        messages: [%{role: "user", content: prompt}]
      }
      |> Jason.encode!()

    call_api(:post, @api_url, headers, body)
  end

  def ask_question_from_ai(question) do
    headers = [
      {"Authorization", "Bearer #{@api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      %{
        model: "perplexity/sonar-pro",
        messages: [%{role: "user", content: question}]
      }
      |> Jason.encode!()

    call_api(:post, @api_url, headers, body)
  end

  def chat_with_geora(prompt) do
    headers = [
      {"Authorization", "Bearer #{@api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      %{
        model: "perplexity/sonar-pro",
        messages: [%{role: "user", content: prompt}]
      }
      |> Jason.encode!()

    call_api(:post, @api_url, headers, body)
  end

  defp call_api(method, url, headers, body) do
    case Finch.build(method, url, headers, body)
         |> Finch.request(MentionScore.Finch) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, format_response(body)}

      {:ok, %Finch.Response{status: status, body: body}} when status > 299 ->
        {:error, format_response(body)}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, status, format_response(body)}

      {:error, reason} ->
        {:error, reason}

      _ ->
        :ok
    end
  end

  defp format_response(body) do
    case Jason.decode(body) do
      {:ok, decoded_body} -> decoded_body
      {:error, reason} -> reason
    end
  end
end
