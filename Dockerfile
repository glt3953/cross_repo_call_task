FROM swift:5.9

WORKDIR /workspace

RUN apt-get update && apt-get install -y python3 python3-pip
RUN pip3 install pytest

COPY Package.swift .
COPY Sources ./Sources
COPY Solutions ./Solutions
COPY test.sh test_state.py solve.sh ./

RUN swift build

CMD ["./test.sh"]
