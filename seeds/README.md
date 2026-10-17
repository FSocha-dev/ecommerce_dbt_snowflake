# Dane syntetyczne do MVP

Pliki służą do nauki modelowania, agregacji i testowania. Nie zawierają danych rzeczywistych osób; adresy e-mail używają domeny example.com.

| Plik | Liczba wierszy | Jeden wiersz |
|---|---:|---|
| raw_customers.csv | 8 | Klient |
| raw_products.csv | 6 | Produkt |
| raw_orders.csv | 10 | Zamówienie |
| raw_order_items.csv | 14 | Pozycja zamówienia |
| raw_payments.csv | 13 | Próba płatności |

## Definicje i założenia

- Wszystkie kwoty są w PLN. Kwoty zapisujemy z kropką dziesiętną.
- `order_total` jest sumą `quantity * unit_price` dla pozycji zamówienia. W MVP nie modelujemy oddzielnie podatków, rabatów, zwrotów ani kosztów dostawy.
- `unit_price` oznacza cenę w momencie zakupu. Może różnić się od aktualnej ceny `catalog_price`; do obliczania wartości pozycji używamy `unit_price`.
- Daty i godziny są umownie w UTC, zapisane bez oznaczenia strefy i ładowane jako `TIMESTAMP_NTZ`.
- Statusy zamówień po oczyszczeniu: `pending`, `paid`, `shipped`, `delivered`, `cancelled`.
- Statusy płatności po oczyszczeniu: `pending`, `success`, `failed`. Tylko `success` zwiększa sumę otrzymanych płatności.
- `amount` dla nieudanej lub oczekującej próby jest kwotą tej próby, a nie otrzymaną płatnością.
- Puste `paid_at` oznacza brak skutecznego opłacenia danej próby; nie jest błędem danych.
- W tym zbiorze statusy `paid`, `shipped` i `delivered` wymagają pełnego opłacenia. `pending` dopuszcza brak lub część płatności.
- Na potrzeby MVP wartość sprzedaży liczymy po dacie zamówienia dla statusów `paid`, `shipped` i `delivered`. Jest to uproszczona definicja projektowa, nie definicja przychodu księgowego.

## Scenariusze do modeli i testów

| Przypadek | Przykład |
|---|---|
| Kilka pozycji i kilka skutecznych płatności | Zamówienia 1001 i 1005 |
| Nieudana próba, a potem skuteczna płatność | Zamówienie 1008 |
| Częściowe opłacenie: 50,00 z 199,80 PLN | Zamówienie 1007 |
| Oczekująca płatność, brak otrzymanych środków | Zamówienie 1003 |
| Anulowanie i nieudana płatność | Zamówienie 1004 |
| Klienci bez zamówień | Klienci 7 i 8 |
| Produkt bez sprzedaży | Produkt 106 |
| Ponowne zakupy klienta | Na przykład klient 1 |
| Różna wielkość liter i zbędne odstępy | Nazwy, e-maile, kategorie i statusy |

W staging stosujemy `trim` i odpowiednio `lower` lub `upper`. Powyższe warianty tekstowe są celowe. Testy dozwolonych statusów powinny działać na oczyszczonych wartościach.

## Problem zwielokrotnienia wierszy

Zamówienie 1001 ma dwie pozycje o łącznej wartości 249,80 PLN i dwie płatności o łącznej wartości 249,80 PLN. Bezpośredni JOIN pozycji z płatnościami po `order_id` tworzy cztery wiersze i zawyża obie sumy do 499,60 PLN.

W modelu zamówień najpierw osobno agregujemy pozycje i skuteczne płatności do jednego wiersza na zamówienie, a następnie łączymy te agregaty.

## Ładowanie

Wykonaj na Macu, w głównym katalogu projektu, przy działającym kontenerze:

```bash
docker exec --env-file .env ecommerce-dbt \
  dbt seed --project-dir /usr/app --profiles-dir /usr/app
```

Konfiguracja projektu i makro `generate_schema_name` kierują wszystkie pięć tabel do `ECOMMERCE.RAW`. Do seedów w modelach odwołujemy się np. przez `{{ ref('raw_customers') }}`.

`properties.yml` zawiera opisy oraz jawne typy kolumn kwotowych i czasowych. Jeżeli po wcześniejszym załadowaniu zmienisz typy lub strukturę CSV, odtwórz tabele seedów przez `dbt seed --full-refresh`. Dla zwykłego pierwszego ładowania wystarcza `dbt seed`.

## Wartości kontrolne

| Miara | Oczekiwany wynik |
|---|---:|
| Suma wartości wszystkich zamówień, także pending i cancelled | 1646,20 PLN |
| Suma skutecznych płatności, także częściowej wpłaty na pending | 1206,90 PLN |
| Wartość zamówień paid, shipped i delivered | 1156,90 PLN |

Suma skutecznych płatności jest o 50,00 PLN większa od zdefiniowanej wartości sprzedaży, ponieważ zamówienie 1007 nadal ma status pending.

Sprawdzenie liczby wierszy w SQL Worksheet w Snowflake:

```sql
USE ROLE ECOMMERCE_DBT;
USE WAREHOUSE ECOMMERCE_WH;

SELECT 'RAW_CUSTOMERS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT
FROM ECOMMERCE.RAW.RAW_CUSTOMERS
UNION ALL
SELECT 'RAW_PRODUCTS', COUNT(*) FROM ECOMMERCE.RAW.RAW_PRODUCTS
UNION ALL
SELECT 'RAW_ORDERS', COUNT(*) FROM ECOMMERCE.RAW.RAW_ORDERS
UNION ALL
SELECT 'RAW_ORDER_ITEMS', COUNT(*) FROM ECOMMERCE.RAW.RAW_ORDER_ITEMS
UNION ALL
SELECT 'RAW_PAYMENTS', COUNT(*) FROM ECOMMERCE.RAW.RAW_PAYMENTS;
```
