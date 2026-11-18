# EndpointSecurityML

MLOps-app som tränar en modell och serverar den. Körs i Docker — du behöver
bara installera Docker Desktop, ingen Python eller databas på din dator.

---

## ⚡ Så här kör du

**Filnamnen är inte i den ordning du ska köra dem.**

### 1. Förberedning (engång)

```powershell
Set-ExecutionPolicy -Scope Process Bypass   # om PowerShell blockerar
.\1setup-folders.ps1
```
Skapar mapparna, `.env` och kontrollerar att Docker är igång.

### 2. Bygg appen (viktigaste steget)

```powershell
.\8setup-api.ps1
```
Startar PostgreSQL + MLflow, genererar träningsdata, tränar en modell och
startar API:t. Tar 10–20 minuter första gången (images byggs).

**Klart.** Öppna <http://localhost:8000/docs> och testa `POST /predict`:
```json
{"NetworkConnections": 25, "ProcessName": "mimikatz.exe", "Username": "attacker"}
```
Svar: `{"prediction": 1, "threat_type": "Attack", ...}`

### 3. Valfritt — lägg till mer

| Skript | Ger dig |
|---|---|
| `9setup-monitoring.ps1` | Prometheus + Grafana (grafer) |
| `10setup-airflow.ps1` | träning varje natt kl. 03:00 |
| `3setup-ml-environment.ps1` | lokal `.venv` för att köra tester |
| `4setup-dvc.ps1` + `5dvc-kommandon.ps1` | versionsstyrd träningsdata |
| `6setup-mlflow.ps1` | MLflow-gränssnitt med accuracy/F1 per körning |
| `11setup-github-actions.ps1` | CI/CD till GitHub |

### Hoppa över helt

`2setup-database.sql` och `7mlflow-kommandon-sqlserver.ps1` gäller bara om du
kör SQL Server. Standardsystemet är PostgreSQL och sätts upp automatiskt.

---

## Vad, varför och hur — alla steg

| Skript | **Vad** det gör | **Varför** du gör det | **Hur** |
|---|---|---|---|
| `1setup-folders.ps1` | Skapar mappar + `.env`, kollar Docker | Docker skapar annars mapparna som *root* — då kan du inte redigera filerna | `.\1setup-folders.ps1` |
| `8setup-api.ps1` | Startar databas + MLflow, genererar data, **tränar modellen**, startar API:t | Enda steget som ger en fungerande app. Utan tränad modell svarar API:t 503 | `.\8setup-api.ps1` |
| `9setup-monitoring.ps1` | Startar Prometheus + Grafana | Du behöver *se* att appen mäter fel, svarar långsamt och fångar attacker | `.\9setup-monitoring.ps1` |
| `10setup-airflow.ps1` | Startar Airflow med 2 DAG:ar | I riktig drift ska träningen ske automatiskt, inte när du minns att köra ett skript | `.\10setup-airflow.ps1` |
| `3setup-ml-environment.ps1` | Skapar `.venv` + installerar bibliotek | Bara för att köra tester lokalt. Appen körs i Docker | `.\3setup-ml-environment.ps1` |
| `4setup-dvc.ps1` | Initierar DVC, spårar `data/raw` | Träningsdata ändras hela tiden — utan versionsstyrning vet du inte vilken data en modell tränades på | `.\4setup-dvc.ps1` |
| `5dvc-kommandon.ps1` | Meny: status, add, commit, push | Enklare än att komma ihåg DVC-kommandona | `.\5dvc-kommandon.ps1` |
| `6setup-mlflow.ps1` | Startar MLflow + kör en träning | Visar accuracy/precision/F1 per körning så du kan jämföra förbättringar | `.\6setup-mlflow.ps1` |
| `11setup-github-actions.ps1` | Skriver CI/CD-instruktioner | `ci.yml` kör testerna på varje push — du hittar buggar innan andra gör det | `.\11setup-github-actions.ps1` |
| `2setup-database.sql` | Skapar SQL Server-tabeller | **Hoppa över** — bara om du kör SQL Server | I SSMS |
| `7mlflow-kommandon-sqlserver.ps1` | MLflow mot SQL Server | **Hoppa över** — bara om du kör SQL Server | `.\7mlflow-kommandon-sqlserver.ps1` |

---

## FAG

**Varför svarar `/predict` med 503?**
Ingen modell finns än. Kör `8setup-api.ps1` — den tränar en.

**Måste jag installera Python?**
Nej. Appen körs helt i Docker. Python behövs bara för `3setup-ml-environment.ps1`
om du vill köra tester lokalt.

**Kan jag hoppa över `2setup-database.sql` och steg 7?**
Ja. De gäller bara SQL Server. PostgreSQL-schema och seed-data skapas
automatiskt när containern startar första gången.

**Hur vet jag att träningen lyckades?**
`8setup-api.ps1` avslutas med en riktig förutsägelse mot den tränade modellen.
Om den steget visas är allt OK.

**Vad gör skillnad mellan 8000 och 8001 i loggar?**
Första talet är porten på din dator, andra är i containern. Ändra bara den
första — och bara i `.env`.

**Var sparas modellen?**
`models/production/endpoint_model_<datum>.pkl`. API:t laddar automatiskt den
**nyaste** filen. Den mappen är git-ignorerad.

**Varför sparas inga modeller i GitHub?**
De är stora binärer. Lägg dem i DVC (`4setup-dvc.ps1`) i stället.

**Kan jag köra om `8setup-api.ps1` flera gånger?**
Ja. Den tar bort gamla containrar, genererar ny data och tränar om.
Modellerna blir fler i `models/production` — gamla kan tas bort.

**Vad är skillnaden mellan `Script_PC`, `_MAC` och `_LINUX`?**
Identiskt innehåll — bara olika skal: PowerShell respektive bash.

---

## Adresser

| | |
|---|---|
| API-dokumentation | <http://localhost:8000/docs> |
| Hälsokontroll | <http://localhost:8000/health> |
| Mätvärden | <http://localhost:8000/metrics> |
| MLflow | <http://localhost:5000> |
| Grafana | <http://localhost:3000> (admin/admin) |
| Prometheus | <http://localhost:9090> |
| Airflow | <http://localhost:8080> (admin/admin) |

---

## Att lösa problem

| Symptom | Orsak och fix |
|---|---|
| `/predict` ger 503 | ingen modell än — kör `8setup-api.ps1` |
| "port is already allocated" | byt port i `.env`, t.ex. `API_PORT=8010` |
| Grafana visar "No data" | inga anrop än — vänta 30 s efter första förfrågan |
| ändringar i `src\` syns inte | Docker Desktop → Resources → **File sharing** |
| Airflow startar om | `docker compose logs airflow-init` |
| `pytest` kraschar | använd `.venv` från `3setup-ml-environment.ps1` |

---

## Kommandon

| Jag vill... | Kommando |
|---|---|
| Starta allt | `docker compose --profile '*' up -d` |
| Status | `docker compose ps` |
| Loggar | `docker compose logs -f api` |
| Träna om | `docker compose --profile training run --rm trainer` |
| Stänga av | `docker compose --profile '*' down` |
| Radera all data | `docker compose --profile '*' down -v` |

---

## Det viktigaste att förstå

Alla delar delar **en enda feature-lista** i `src/api/utils.py`:

```python
FEATURE_NAMES = ["NetworkConnections", "IsSystemUser", "IsSuspiciousProcess"]
```

Träningsskripten och API:t **importerar** den i stället för att skriva egen.
Det är därför träning och servering alltid fungerar ihop.

Felsöker du en modell i API:t? Kolla först: `model.n_features_in_` ska vara **3**.

---

## Struktur

```
src/api/          app.py, models.py, utils.py  (tjänsten)
src/training/     träningsskript
src/data_generation/  skapar träningsdata
airflow/dags/     schemalagda jobb
postgres/init/    schema + seed (körs automatiskt)
grafana/          dashboard
k8s/              Kubernetes-manifest
tests/            tester
```
