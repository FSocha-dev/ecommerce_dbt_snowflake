FROM python:3.12-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DBT_SEND_ANONYMOUS_USAGE_STATS=false

RUN python -m pip install --no-cache-dir \
    dbt-core==1.12.0 \
    dbt-snowflake==1.12.0 \
    && python -m pip check

WORKDIR /usr/app

CMD ["sleep", "infinity"]