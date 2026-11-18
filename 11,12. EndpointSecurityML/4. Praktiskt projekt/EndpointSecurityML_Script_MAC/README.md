# EndpointSecurityML

MLOps-app som tränar en modell och serverar den. Körs i Docker — du behöver
bara installera Docker, ingen Python eller databas på din dator.

---

## ⚡ Så här kör du

**Filnamnen är inte i den ordning du ska köra dem.**

### Installera Docker (engång)

*macOS:* Docker Desktop från <https://docs.docker.com/desktop/install/mac-install/>

*Linux:*
```bash
sudo apt install -y docker.io docker-compose-v2   # Debian/Ubuntu
sudo usermod -aG docker "$USER" && newgrp docker
```

### 1. Förberedning (engång)

```bash
chmod +x *.sh
./1setup-folders.sh
```
Skapar mapparna, `.env` och kontrollerar att Docker är igång.

### 2. Bygg appen (viktigaste steget)

```bash
./8setup-api.sh
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
| `./9setup-monitoring.sh` | Prometheus + Grafana (grafer) |
| `./10setup-airflow.sh` | träning varje natt kl. 03:00 |
| `./3setup-ml-environment.sh` | lokal `.venv` för att köra tester |
| `./4setup-dvc.sh` + `./5dvc-kommandon.sh` | versionsstyrd träningsdata |
| `./6setup-mlflow.sh` | MLflow-gränssnitt med accuracy/F1 per körning |
| `./11setup-github-actions.sh` | CI/CD till GitHub |

### Hoppa över helt

`2setup-database.sql` och `./7mlflow-kommandon-sqlserver.sh` gäller bara om du
kör SQL Server. Standardsystemet är PostgreSQL och sätts upp automatiskt.

---

## Vad, varför och hur — alla steg

| Skript | **Vad** det gör | **Varför** du gör det | **Hur** |
|---|---|---|---|
| `./1setup-folders.sh` | Skapar mappar + `.env`, kollar Docker | Docker skapar annars mapparna som *root* — då kan du inte redigera filerna | `./1setup-folders.sh` |
| `./8setup-api.sh` | Startar databas + MLflow, genererar data, **tränar modellen**, startar API:t | Enda steget som ger en fungerande app. Utan tränad modell svarar API:t 503 | `./8setup-api.sh` |
| `./9setup-monitoring.sh` | Startar Prometheus + Grafana | Du behöver *se* att appen mäter fel, svarar långsamt och fångar attacker | `./9setup-monitoring.sh` |
| `./10setup-airflow.sh` | Startar Airflow med 2 DAG:ar | I riktig drift ska träningen ske automatiskt, inte när du minns att köra ett skript | `./10setup-airflow.sh` |
| `./3setup-ml-environment.sh` | Skapar `.venv` + installerar bibliotek | Bara för att köra tester lokalt. Appen körs i Docker | `./3setup-ml-environment.sh` |
| `./4setup-dvc.sh` | Initierar DVC, spårar `data/raw` | Träningsdata ändras hela tiden — utan versionsstyrning vet du inte vilken data en modell tränades på | `./4setup-dvc.sh` |
| `./5dvc-kommandon.sh` | Meny: status, add, commit, push | Enklare än att komma ihåg DVC-kommandona | `./5dvc-kommandon.sh` |
| `./6setup-mlflow.sh` | Startar MLflow + kör en träning | Visar accuracy/precision/F1 per körning så du kan jämföra förbättringar | `./6setup-mlflow.sh` |
| `./11setup-github-actions.sh` | Skriver CI/CD-instruktioner | `ci.yml` kör testerna på varje push — du hittar buggar innan andra gör det | `./11setup-github-actions.sh` |
| `2setup-database.sql` | Skapar SQL Server-tabeller | **Hoppa över** — bara om du kör SQL Server | I SSMS |
| `./7mlflow-kommandon-sqlserver.sh` | MLflow mot SQL Server | **Hoppa över** — bara om du kör SQL Server | `./7mlflow-kommandon-sqlserver.sh` |

---

## FAG

**Varför svarar `/predict` med 503?**
Ingen modell finns än. Kör `./8setup-api.sh` — den tränar en.

**Måste jag installera Python?**
Nej. Appen körs helt i Docker. Python behövs bara för `./3setup-ml-environment.sh`
om du vill köra tester lokalt.

**Kan jag hoppa över `2setup-database.sql` och steg 7?**
Ja. De gäller bara SQL Server. PostgreSQL-schema och seed-data skapas
automatiskt när containern startar första gången.

**Hur vet jag att träningen lyckades?**
`./8setup-api.sh` avslutas med en riktig förutsägelse mot den tränade modellen.
Om den steget visas är allt OK.

**Vad gör skillnad mellan 8000 och 8001 i loggar?**
Första talet är porten på din dator, andra är i containern. Ändra bara den
första — och bara i `.env`.

**Var sparas modellen?**
`models/production/endpoint_model_<datum>.pkl`. API:t laddar automatiskt den
**nyaste** filen. Den mappen är git-ignorerad.

**Varför sparas inga modeller i GitHub?**
De är stora binärer. Lägg dem i DVC (`./4setup-dvc.sh`) i stället.

**Kan jag köra om `./8setup-api.sh` flera gånger?**
Ja. Den tar bort gamla containrar, genererar ny data och tränar om.
Modellerna blir fler i `models/production` — gamla kan tas bort.

**Får jag "Permission denied" när jag kör ett skript?**
Kör `chmod +x *.sh` en gång. Behövs bara efter att du kopierat filerna.

**Vad är skillnaden mellan `_MAC` och `_LINUX`?**
Identiskt innehåll. Enda verkliga skillnaden: macOS kräver File sharing i
Docker Desktop, Linux har inbyggda bind mounts. Installationsstegen skiljer sig.

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
| `/predict` ger 503 | ingen modell än — kör `./8setup-api.sh` |
| `Permission denied` på `.sh` | `chmod +x *.sh` |
| `permission denied` på Docker | `sudo usermod -aG docker $USER`, logga ut/in |
| root-ägda filer i mappen | `sudo chown -R "$(id -u)" .` (kontrollera `DVC_UID` i `.env`) |
| `bad interpreter: /usr/bin/env bash^M` | filen har CRLF — konvertera till LF |
| ändringar i `src/` syns inte | macOS: Docker Desktop → Resources → **File sharing** |
| "port is already allocated" | byt port i `.env`, t.ex. `API_PORT=8010` |
| Grafana visar "No data" | inga anrop än — vänta 30 s efter första förfrågan |

---

## Kommandon

| Jag vill... | Kommando |
|---|---|
| Starta allt | `docker compose --profile '*' up -d` |
| Status | `docker compose ps` |
| Loggar | `docker compose logs -f api` |
| Träna om | `docker compose --profile training run --rm trainer` |
| Köra tester | `.venv/bin/python -m pytest tests/ -v` |
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
