import pathlib
import sys

root = pathlib.Path(sys.argv[1])
tables = set('catalog_page catalog_returns customer customer_address customer_demographics date_dim household_demographics inventory item promotion store store_returns catalog_sales web_sales store_sales web_returns web_site reason call_center warehouse ship_mode income_band time_dim web_page'.split())
for table in sorted(tables):
    directory = root / table
    if not (directory / '_SUCCESS').exists() or not any(directory.rglob('*.parquet')):
        raise SystemExit(f'Incomplete data table: {table}')
print('All 24 Parquet tables have been generated.')
