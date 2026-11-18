# Eget arbete inför varje lektion – flippat klassrum

**Utveckling med Python, fortsättning (40 YH-poäng) · heltidskurs**

> Flippat klassrum: teori, konton och installationer görs hemma – klassrumstiden används till att göra saker. Läraren går inte igenom alla bilder. Missat pass = gör läxan i läxafliken; deltagit = läxan är frivillig, men PowerPointen för nästa pass ska alltid vara läst.

## Lektion för lektion

| Lektion | Tema | Lektionsmapp | Gör hemma | Läs (PowerPoint + begrepp) | Titta/lyssna | Quiz (3. HTML) | Klart när | Missat pass | I klassrummet |
|---|---|---|---|---|---|---|---|---|---|
| 1 | DevOps & Intro Databricks | 1. DevOps & Intro Databricks | 1. Skapa konto på Databricks Free Edition och logga in.<br>2. Compute → Create compute → vänta tills status är grön.<br>3. Ladda ner scb_arbetsmarknad.csv (laddas upp i labben). | 0. DevOps (workshop).pptx (26 bilder) – läs alla.<br>1. Intro Databricks …pptx (104) – referens.<br>Begrepp: silo, DevOps, feedback-loop, pandas vs PySpark, lazy evaluation, Delta Lake, Unity Catalog, GDPR/AI Act. | Intro_Databricks.mp4<br>Hantera_enorma_datamängder_med_Spark_och_Databricks.m4a | [workshop-01-devops-databricks.html](1.%20DevOps%20%26%20Intro%20Databricks/3.%20HTML/workshop-01-devops-databricks.html) – 3 frågor i fliken Individuellt arbete | Inloggning fungerar, klustret startar, quizet gjort. | Läxa 1 | Flygplansövning i grupp 4–5, genomgång, notebook, HTML-pass |
| 2 | Multi-Agent System, del 1 | 2,3. Branschfördjupning – med MAS | 1. Skapa Groq-konto → API Keys → ny nyckel. Spara den.<br>2. Öppna Databricks.<br>3. Workspace → Import → notebooken 15. Branschfördjupning … .ipynb. | Branschfördjupning – med Multi-Agent System.pptx (39 bilder) – läs alla.<br>Begrepp: agent vs prompt, agentloopen, verktyg, REST, JSON, HTTP-status, timeout, Bearer-token, .env vs connection. | Branschfördjupning – med Multi-Agent System.mp4<br>Landa_drömjobbet_med_en_AI-armé.m4a | [workshop-02-multi-agent-del1.html](2%2C3.%20Branschf%C3%B6rdjupning%20%E2%80%93%20med%20MAS/3.%20HTML/workshop-02-multi-agent-del1.html) – 3 frågor i fliken Individuellt arbete | Nyckeln finns, notebooken öppnar, du kan förklara vad ett verktyg är. | Läxa 2 | Genomgång, demo, du bygger Agent 1 (Groq) och Agent 2 (JobTech) |
| 3 | Multi-Agent System, del 2 | 2,3. Branschfördjupning – med MAS | 1. Skapa konto på Tavily (tavily.com) → API Keys → kopiera nyckeln. Behövs för Agent 4.<br>2. Ha kvar Groq-nyckeln och notebooken.<br>3. Kontrollera att klustret är igång. | Samma PPT som lektion 2 (39 bilder), andra halvan.<br>Begrepp: embeddings, NER, chunkning, agentkedja, felhantering, validering av fält. | Samma video och podd som lektion 2 | [workshop-03-multi-agent-del2.html](2%2C3.%20Branschf%C3%B6rdjupning%20%E2%80%93%20med%20MAS/3.%20HTML/workshop-03-multi-agent-del2.html) – 3 frågor i fliken Individuellt arbete | Tavily-nyckeln finns, du kan skilja på en prompt och en agentkedja. | Läxa 3 | Embeddings och NER som teori, du bygger Agent 3 (stack-analys) och Agent 4 (certifieringar) i par och kopplar kedjan |
| 4 | Enterprise stack, del 1 (data och databas) | 4,5. Insider Threat Detection | 1. Snowflake Free Trial (Enterprise) – skriv ner account, användare, lösenord.<br>2. dbt Cloud-konto (Developer).<br>3. Läs HANDLEDNING.md steg 1–5.<br>OBS: trialen gäller 30 dagar – kan ha gått ut till lektion 5. | Insider Threat Detection.pptx (135 bilder) – referens.<br>Begrepp: datalager, OLTP vs OLAP, ETL vs ELT, staging, features, dbt-modeller, datakvalitet. | Detektion_av_Insiderhot.mp4<br>Från_stökig_CSV_till_automatiserad_AI-detektiv.m4a | [workshop-04-enterprise-stack-del1.html](4%2C5.%20Insider%20Threat%20Detection/3.%20HTML/workshop-04-enterprise-stack-del1.html) – 3 frågor i fliken Individuellt arbete | Du kan logga in i Snowflake och dbt Cloud, CSV:n finns i mappen. | Läxa 4 | Ladda upp CSV, tre dbt-filer, dbt run, HTML-pass |
| 5 | Enterprise stack, del 2 (modellerna) | 4,5. Insider Threat Detection | 1. Kontrollera att tabellen FCT_FEATURES finns i Snowflake.<br>2. Ladda upp databricks_steps_8-14.ipynb.<br>3. Valfritt: Slack-webhook och Groq-nyckel för automatiseringssteget. | Samma PPT som lektion 4 (135 bilder), andra halvan.<br>Begrepp: Random Forest vs Isolation Forest, accuracy-fällan, precision, recall, F1, confusion matrix, MLflow och Run ID, drift. | Samma video och podd som lektion 4 | [workshop-05-enterprise-stack-del2.html](4%2C5.%20Insider%20Threat%20Detection/3.%20HTML/workshop-05-enterprise-stack-del2.html) – 3 frågor i fliken Individuellt arbete | Du kan förklara precision och recall utan anteckningar. | Läxa 5 | Steg 8–11, A/B-jämförelse, export |
| 6 | AI Agent Engineering (lokalt) | 6. AI Agent Engineering | 1. Installera Python 3.12 (3.11 går).<br>2. VS Code + Python-tillägg.<br>3. Git.<br>4. LM Studio + mindre modell (4–8 GB), Developer → Start Server.<br>5. Packa upp ai-agent-engineering-app.<br>6. Kör .\setup-lesson6.ps1, välj 1 och 2 – båda ska bli gröna.<br>7. OpenAI/Groq-nyckel behövs bara för molnexemplen. | 6. AI Agent Engineering.pptx (74 bilder).<br>Begrepp: agentloop, tools/function calling, Pydantic structured output, guardrails, human-in-the-loop, MCP. | Inget – 1. Multimedia är tom för det här passet | [workshop-06-ai-agent-engineering.html](6.%20AI%20Agent%20Engineering/3.%20HTML/workshop-06-ai-agent-engineering.html) – 3 frågor i fliken Individuellt arbete | python --version ≥ 3.11, LM Studio svarar, menyval 1–2 gröna. | Läxa 6 | Läraren visar exempel 1–3, du gör samma, därefter 4–6 (HITL, validering, guardrail) |
| 7 | AI Support Agent med RAG | 7. AI Agent | 1. Docker Desktop igång, ca 4 GB RAM ledigt.<br>2. Kopiera .env.example → .env och fyll i GROQ_API_KEY eller OPENAI_API_KEY.<br>3. docker compose up --build -d (flera minuter första gången).<br>4. Kör verify-docker.ps1/.sh och öppna localhost:8501.<br>Portarna 8501, 8000, 6006 och 11434 ska vara lediga. | 7. AI Agent Engineering — vad kan vi bygga.pptx (48 bilder).<br>Begrepp: RAG, embeddings, chunkning, Chroma, retriever, LangGraph, evals, tracing, image/container/compose. | AI_Agent_Engineering.mp4<br>Från_bräcklig_AI-demo_till_stabil_produktion.m4a | [workshop-07-ai-support-agent.html](7.%20AI%20Agent/3.%20HTML/workshop-07-ai-support-agent.html) – 3 frågor i fliken Individuellt arbete | docker compose ps visar app, Chroma och Phoenix, och appen har öppnats. | Läxa 7 | Bygg kunskapsbasen, kurssteg 1–9 i appen |
| 8 | Git-workshop och code review | 8. Git-workshop | 1. GitHub-konto klart och e-post verifierad – före lektionen.<br>2. Git installerat + git config user.name / user.email.<br>3. python -m pytest --version fungerar.<br>4. Partner bestämd (övningen kräver två).<br>5. Läs workshop_instruktioner.md steg 0. | 8. Git-workshop.pptx (9 bilder) – bara flödet.<br>Begrepp: feature branch, pull request, 1+1-regeln, merge-konflikt, squash & merge, pytest, CI. | Code_Review_i_AI-projekt.mp4<br>Kodgranskning_och_1_plus_1-regeln_i_AI-projekt.m4a | [workshop-08-git-code-review.html](8.%20Git-workshop/3.%20HTML/workshop-08-git-code-review.html) – 3 frågor i fliken Individuellt arbete | GitHub-inloggning fungerar, git config svarar, partner klar. | Läxa 8 + parövningen med en kurskamrat | Repo, branch, pull request, 1+1-review, squash & merge, pytest på main |
| 9 | ML för nätverkssäkerhet, del 1 | 9,10. ML för analys av stora datamängder | 1. SQL Server Express (välj Basic) + SSMS.<br>2. Microsoft ODBC Driver 17 for SQL Server.<br>3. Google-konto, kontrollera att Colab fungerar.<br>4. Power BI Desktop (bara Windows).<br>Mac: prata med läraren före lektionen. | Maskininlärning för nätverkssäkerhet … .pptx (71 bilder).<br>Begrepp: klassificering, features, train/test, confusion matrix, precision och recall, syntetisk data. | AI-driven_hotdetektor.mp4<br>Bygg_ett_automatiserat_nätverksförsvar_med_maskininlärning.m4a | [workshop-09-ml-lokal-miljo.html](9%2C10.%20ML%20f%C3%B6r%20analys%20av%20stora%20datam%C3%A4ngder/3.%20HTML/workshop-09-ml-lokal-miljo.html) – 3 frågor i fliken Individuellt arbete | SSMS ansluter, Colab fungerar, drivrutinen är installerad. | Läxa 9 (täcker lektion 9 och 10) | create_tables.sql i SSMS (3 tabeller, 1 vy, 20 testrader), träning i Colab |
| 10 | Automatiserad pipeline och Power BI | 9,10. ML för analys av stora datamängder | 1. Databasen NetworkSecurityML finns (annars create_tables.sql, F5).<br>2. Kör run_ml_analysis.ps1 en gång – ändra inte paketversionerna.<br>3. Öppna NetworkSecurityReportPowerBI.pbix.<br>PowerShell-block? Set-ExecutionPolicy -Scope Process Bypass. | Samma PPT som lektion 9 (71 bilder), andra halvan.<br>Begrepp: inkrementell bearbetning, IsProcessed = 0, portabla sökvägar, tröskelvärde, konfidens, SQL-vyn som skikt. | Samma video och podd som lektion 9 | [workshop-10-automatiserad-pipeline.html](9%2C10.%20ML%20f%C3%B6r%20analys%20av%20stora%20datam%C3%A4ngder/3.%20HTML/workshop-10-automatiserad-pipeline.html) – 3 frågor i fliken Individuellt arbete | Skriptet har kört utan fel och .pbix-filen öppnar. | Läxa 9 (pipeline och rapportvy) | Servernamn i skriptet, kör analysen, verifiera i SQL, kör igen, koppla Power BI |
| 11 | MLOps och REST API | 11,12. EndpointSecurityML | 1. Docker Desktop igång, 10–20 GB ledig disk.<br>2. Kör python control-center/server.py i EndpointSecurityML_Docker.<br>3. Öppna 127.0.0.1:8765 → starta API och PostgreSQL (10–20 min första gången).<br>4. Portarna 8000, 5000, 5432, 8080, 3000, 9090 lediga. | AI för detektering … .pptx (189 bilder) – referens.<br>Begrepp: MLOps, MLflow vs DVC, container vs VM, FastAPI, StrictInt/StrictFloat → HTTP 422, POST /predict, pytest. | AI-drivet_cybersäkerhetssystem.mp4<br>Bygg_en_robust_MLOps-fästning_mot_ransomware.m4a | [workshop-11-mlops-rest-api.html](11%2C12.%20EndpointSecurityML/3.%20HTML/workshop-11-mlops-rest-api.html) – 3 frågor i fliken Individuellt arbete | Kontrollpanelen visar grönt, /docs svarar, en prediktion gjord. | Läxa 10 | Starta tjänsterna, ladda exempeldata, träna, MLflow, DVC, POST /predict |
| 12 | Containers, Airflow och projektstart | 11,12. EndpointSecurityML | 1. Docker Hub-konto → Account settings → Security → New Access Token.<br>2. Tomt GitHub-repo för projektet.<br>3. Starta Airflow + övervakning en gång (README: Lägg till Airflow och övervakning).<br>4. Läs Projekt v1/v2 och välj projektidé. | Samma PPT som lektion 11 (189 bilder), sista delen.<br>Begrepp: DAG, Compose vs Kubernetes, CI/CD, Prometheus/Grafana, vad som skiljer G från VG. | Samma video och podd som lektion 11 | [workshop-12-containers-airflow.html](11%2C12.%20EndpointSecurityML/3.%20HTML/workshop-12-containers-airflow.html) – 3 frågor i fliken Individuellt arbete | Docker Hub-konto, tomt repo och en projektidé. | Läxa 10 (Docker-delen) + README för Airflow/Grafana | Airflow-DAG:en endpointsecurity_train_model, Grafana, GitHub Actions, Docker Hub, projektbrief |

## Så räknar du tiden

| Var | Tid per vecka | Vad du gör |
|---|---|---|
| Lärarledda pass | ca 12 h | Video, grundmoment, quiz, HTML-pass, labb, projekt, frågor. |
| Eget arbete – förberedelse | ca 6–8 h | Media, PowerPoint, quiz och teknik inför nästa pass. 3–5 h per lektion. |
| Eget arbete – läxa och projekt | ca 20–22 h | Läxa (krav vid missat pass), examinationsprojektet, repetition. |
| Summa | ca 40 h | Kursen är en heltidskurs. Klassrumstiden räcker inte. |

## Konton och program

| Konto / program | Behövs till | Kostnad |
|---|---|---|
| Databricks Free Edition | Lektion 1–5 | Gratis |
| Groq (API-nyckel) | Lektion 2–3 (valfritt i 5–6) | Gratis |
| Tavily (API-nyckel) | Lektion 3 | Gratis |
| Snowflake (Free Trial) | Lektion 4–5 | 30 dagar gratis |
| dbt Cloud (Developer) | Lektion 4–5 | Gratis |
| Python 3.12 + VS Code + Git | Lektion 6 och framåt | Gratis |
| LM Studio | Lektion 6 | Gratis |
| Docker Desktop | Lektion 7, 11, 12 | Gratis för kursen |
| GitHub | Lektion 8 och projektet | Gratis |
| SQL Server Express + SSMS | Lektion 9–10 | Gratis |
| ODBC Driver 17 for SQL Server | Lektion 10 | Gratis |
| Google-konto (Colab) | Lektion 9 | Gratis |
| Power BI Desktop | Lektion 10 | Gratis |
| Docker Hub | Lektion 12 | Gratis |
| OpenAI-nyckel (valfritt) | Lektion 6–7 | Betalt per användning |

## Ordlista

| Ord | Förklaring |
|---|---|
| Databricks | Molntjänst i webbläsaren där du kör Python och SQL på stora data. |
| PySpark | Verktyg för data som är för stor för en vanlig dator. |
| Snowflake | Databas i molnet, byggd för stora mängder data. |
| dbt | Bygger tabeller med SQL, så du slipper göra om samma sak manuellt. |
| MLflow | Loggbok för modellträning: vilka inställningar gav vilket resultat. |
| DVC | Versionshantering för stora filer, till exempel modeller. |
| Docker | Paketerar ett program med allt det behöver, så det körs likadant överallt. |
| API | Sätt för program att prata med varandra. |
| RAG | Låter en AI söka i dokument först och svara med källor. |
| Guardrail | Skyddsregel som stoppar en AI från att göra något olämpligt. |

## Efter sista lektionen

| Steg | Vad som händer | Vad du ska göra |
|---|---|---|
| 1 | Eget projektarbete | Bygga, testa och dokumentera projektet |
| 2 | Handledning | Ta med körbar kod, README-utkast och frågor |
| 3 | Inlämning | .zip på lärarplattformen + GitHub-länk i README.md |
| 4 | Examination | Teorikontroll (2–5 frågor) + projektredovisning |

Datum och tider för inlämning och examination får du av läraren och står i kursplaneringen.

## Om något inte fungerar

1. Läs felmeddelandet en gång till – det står oftast vilken fil eller vilket paket som saknas.
2. Kontrollera att du är i rätt mapp i terminalen.
3. Skriv i klassens kanal före passet och klistra in felmeddelandet.

---

_Källa: fliken **Eget arbete inför lektion** i `Kursplanering Utveckling med Python, fortsättning.xlsx`._
