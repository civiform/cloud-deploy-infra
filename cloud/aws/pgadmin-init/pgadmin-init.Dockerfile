FROM python:3-slim

COPY main.py /main.py

CMD ["python", "/main.py"]
