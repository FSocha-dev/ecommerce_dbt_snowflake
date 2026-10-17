# E-commerce Data Warehouse — dbt + Snowflake

Projekt przedstawiający budowę hurtowni
danych sprzedażowych dla sklepu internetowego.

## Cel biznesowy
Udostępnienie spójnych danych do analizy:
- wartości zamówień i dziennej sprzedaży;
- płatności oraz stopnia opłacenia zamówień;
- aktywności klientów;
- sprzedaży poszczególnych produktów.

## Technologie
- Snowflake — przechowywanie danych i wykonywanie transformacji.
- dbt Core + dbt snowflake — modele SQL, testy i dokumentacja.
- Docker — lokalne środowisko uruchamiania dbt.
- Python — docelowe ładowanie danych CSV do Snowflake.
- Git i GitHub — wersjonowanie kodu.

## Dane źródłowe
Projekt wykorzystuje syntetyczne dane CSV:
- customers;
- orders;
- order_items;
- products;
- payments.

## Planowana architektura
CSV → Snowflake RAW → dbt staging → modele analityczne

Warstwa staging odpowiada za ujednolicenie typów danych,
oczyszczenie wartości i przygotowanie źródeł do dalszych transformacji.

## Modele analityczne
dim_customers - Jeden klient
dim_products - Jeden produkt
fct_order_items - Jedna pozycja zamówienia
fct_orders - Jedno zamówienie
mart_daily_sales - Jeden dzień sprzedaży

## Zakres MVP
1. Konfiguracja Snowflake i lokalnego środowiska Docker.
2. Przygotowanie syntetycznych danych i ładowanie przez dbt seed.
3. Budowa modeli staging.
4. Budowa wymiarów, faktów i zestawienia dziennej sprzedaży.
5. Dodanie testów oraz dokumentacji dbt.

## Ładowanie danych CSV do Snowflake

W MVP dane syntetyczne z katalogu `seeds/` ładujemy przez `dbt seed`.
Polecenie wykonujemy w terminalu na Macu, w głównym katalogu projektu,
przy uruchomionym Docker Desktop i kontenerze `ecommerce-dbt`:

```bash
docker exec --env-file .env ecommerce-dbt \
  dbt seed --project-dir /usr/app --profiles-dir /usr/app
```

| Fragment | Znaczenie |
|---|---|
| `docker exec` | Uruchamia dodatkowy proces w już działającym kontenerze. Nie tworzy nowego kontenera. |
| `--env-file .env` | Docker odczytuje lokalny plik `.env` na Macu i przekazuje zmienne do uruchamianego procesu, w tym hasło do klucza. |
| `ecommerce-dbt` | Nazwa kontenera, w którym wykonujemy polecenie. |
| `dbt seed` | dbt odczytuje pliki CSV i ładuje je do tabel w Snowflake. |
| `--project-dir /usr/app` | Wskazuje katalog projektu wewnątrz kontenera, zawierający `dbt_project.yml`. |
| `--profiles-dir /usr/app` | Wskazuje katalog wewnątrz kontenera, zawierający konfigurację połączenia `profiles.yml`. |
| `\` na końcu wiersza | Kontynuuje to samo polecenie w następnym wierszu terminala. |

Podczas tworzenia kontenera zamontowaliśmy katalog projektu przez
`-v "$PWD:/usr/app"`. Dzięki temu dbt widzi lokalne CSV, konfigurację
i klucze w `/usr/app`; nie trzeba osobno kopiować plików do kontenera.

Przebieg ładowania:

1. Docker uruchamia dbt wewnątrz lokalnego kontenera.
2. dbt odczytuje konfigurację projektu oraz profil połączenia.
3. dbt używa klucza prywatnego do uwierzytelnienia w Snowflake.
4. dbt odczytuje CSV z katalogu `seeds/`.
5. Przez połączenie sieciowe dbt wysyła polecenia SQL i dane do Snowflake,
   gdzie powstają tabele oraz zapisywane są ich wiersze.
6. Wynik wykonania jest wyświetlany w terminalu. Kontener pozostaje uruchomiony.

```text
Mac: seeds/*.csv
    → lokalny kontener: /usr/app/seeds/*.csv
    → dbt i adapter Snowflake
    → połączenie sieciowe
    → tabele w ECOMMERCE.RAW w Snowflake
```

`docker exec` uruchamia lokalny proces; dopiero dbt łączy się ze zdalnym
Snowflake. Klucz prywatny i hasło do jego odszyfrowania pozostają po stronie
klienta i nie są przesyłane do Snowflake.

Przy pierwszym ładowaniu dbt tworzy pięć tabel:
`RAW_CUSTOMERS`, `RAW_PRODUCTS`, `RAW_ORDERS`, `RAW_ORDER_ITEMS`
i `RAW_PAYMENTS` w schemacie `ECOMMERCE.RAW`. Wybór schematu wynika
z konfiguracji `seeds` i makra `generate_schema_name`.

Ponowne wykonanie `dbt seed` dla tych seedów zastępuje zawartość tabel
danymi z CSV; nie dopisuje kolejnej kopii tych samych wierszy.
Polecenie nie uruchamia modeli staging ani marts — do tego służy `dbt run`.

Opisy danych, scenariusze i wartości kontrolne: [seeds/README.md](seeds/README.md).

Dokumentacja: [Docker exec](https://docs.docker.com/reference/cli/docker/container/exec/)
i [dbt seed](https://docs.getdbt.com/reference/commands/seed).
