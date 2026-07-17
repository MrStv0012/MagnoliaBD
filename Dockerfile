FROM postgres:16-bookworm
COPY *.sql /docker-entrypoint-initdb.d/

ENV POSTGRES_USER=u_magnolia
ENV POSTGRES_PASSWORD=m4gn0l14
ENV POSTGRES_DB=db_magnolia
