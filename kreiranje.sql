BEGIN;

CREATE TABLE usluga (
uslugaID SERIAL PRIMARY KEY,
naziv VARCHAR(50) NOT NULL,
opis VARCHAR(100),
datum DATE NOT NULL
);

CREATE TABLE cijena (
cijenaID SERIAL PRIMARY KEY,
uslugaID INT REFERENCES usluga(uslugaID) ON DELETE CASCADE,
rata NUMERIC(10, 2) NOT NULL,
datum DATE NOT NULL
);

CREATE TABLE trajanje (
trajanjeID SERIAL PRIMARY KEY,
uslugaID INT REFERENCES usluga(uslugaID) ON DELETE CASCADE,
pocetak TIMESTAMP NOT NULL,
zavrsetak TIMESTAMP NOT NULL
);

CREATE TABLE trosak (
uslugaID INT REFERENCES usluga(uslugaID) ON DELETE CASCADE,
trajanjeID INT REFERENCES trajanje(trajanjeID) ON DELETE CASCADE,
ukupno NUMERIC(10, 2) NOT NULL,
PRIMARY KEY(uslugaID, trajanjeID)
);

CREATE OR REPLACE FUNCTION provjeri_vrijeme()
RETURNS TRIGGER
AS $$
BEGIN
IF NEW.pocetak < (SELECT datum FROM usluga WHERE uslugaID = NEW.uslugaID) THEN
RAISE EXCEPTION 'Početak ne može biti prije usluge!';
END IF;
IF NEW.pocetak < (SELECT MIN(datum) FROM cijena WHERE uslugaID = NEW.uslugaID) THEN
RAISE EXCEPTION 'Početak ne može biti prije cijene usluge!';
END IF;
IF NEW.zavrsetak < NEW.pocetak THEN
RAISE EXCEPTION 'Završetak ne može biti prije početka!';
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER provjeri_vrijeme_t
BEFORE INSERT
ON trajanje
FOR EACH ROW
EXECUTE PROCEDURE provjeri_vrijeme();

CREATE OR REPLACE FUNCTION izracunaj_trosak()
RETURNS TRIGGER
AS $$
DECLARE trenutni_dan TIMESTAMP;
DECLARE pocetak_smjene TIMESTAMP;
DECLARE zavrsetak_smjene TIMESTAMP;
DECLARE trajanje_smjene INTERVAL;
DECLARE trenutna_rata NUMERIC(10, 2);
DECLARE ukupni_trosak NUMERIC(10, 2) := 0;
BEGIN
trenutni_dan := date_trunc('day', NEW.pocetak);
WHILE trenutni_dan <= date_trunc('day', NEW.zavrsetak) LOOP
trenutna_rata := (
SELECT rata
FROM cijena
WHERE uslugaID = NEW.uslugaID
AND datum <= trenutni_dan
ORDER BY datum DESC
LIMIT 1
);
pocetak_smjene := GREATEST(NEW.pocetak, trenutni_dan + INTERVAL '8 hour');
zavrsetak_smjene := LEAST(NEW.zavrsetak, trenutni_dan + INTERVAL '16 hour');
IF pocetak_smjene < zavrsetak_smjene THEN
trajanje_smjene := zavrsetak_smjene - pocetak_smjene;
ukupni_trosak := ukupni_trosak + (EXTRACT(HOUR FROM trajanje_smjene) * trenutna_rata);
END IF;
trenutni_dan := trenutni_dan + INTERVAL '1 day';
END LOOP;
INSERT INTO trosak (uslugaID, trajanjeID, ukupno)
VALUES (NEW.uslugaID, NEW.trajanjeID, ukupni_trosak);
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER izracunaj_trosak_t
AFTER INSERT
ON trajanje
FOR EACH ROW
EXECUTE PROCEDURE izracunaj_trosak();

INSERT INTO usluga (naziv, opis, datum) VALUES ('John Doe', 'freelancer iz microsofta', '2025-01-01');
INSERT INTO usluga (naziv, opis, datum) VALUES ('transformator', 'iznajmljeno iz bauhausa', '2025-05-15');
INSERT INTO usluga (naziv, opis, datum) VALUES ('bager', 'iznajmljeno iz haka', '2025-09-30');

INSERT INTO cijena (uslugaID, rata, datum) VALUES (1, 10.00, '2025-01-01');
INSERT INTO cijena (uslugaID, rata, datum) VALUES (1, 1.00, '2025-01-21');

INSERT INTO trajanje (uslugaID, pocetak, zavrsetak) VALUES (1, '2025-01-01 08:00:00', '2025-02-01 16:00:00');
INSERT INTO trajanje (uslugaID, pocetak, zavrsetak) VALUES (1, '2025-01-01 08:00:00', '2025-01-02 17:00:00');
INSERT INTO trajanje (uslugaID, pocetak, zavrsetak) VALUES (1, '2025-01-01 08:00:00', '2025-01-01 17:00:00');
INSERT INTO trajanje (uslugaID, pocetak, zavrsetak) VALUES (1, '2025-01-21 08:00:00', '2025-01-21 17:00:00');

COMMIT;
