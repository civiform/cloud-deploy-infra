FROM dpage/pgadmin4:6.15

USER root

COPY init.py /init.py

RUN chown pgadmin:root /init.py /pgadmin4

USER pgadmin

ENTRYPOINT ["/bin/sh", "-c"]

CMD ["python3 /init.py; /entrypoint.sh"]
