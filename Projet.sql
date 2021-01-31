--1. Etude Globale

--a. Répartition Adhérant / VIP
select count(vip) from client where vip = 1;
select count(datedebutadhesion) from client where extract(year from datedebutadhesion) = 2016 and vip = 0;
select count(datedebutadhesion) from client where extract(year from datedebutadhesion) = 2017 and vip = 0;
select count(date(datefinadhesion)) from client where date(datefinadhesion) > '20180101' and vip = 0
and extract(year from datedebutadhesion) not in (2016,2017);
select count(date(datefinadhesion)) from client where date(datefinadhesion) < '20180101' and vip = 0
and extract(year from datedebutadhesion) not in (2016,2017);

--b. Comportement du CA GLOBAL par client N-2 vs N-1
select idclient, sum(tic_totalttc) from entete_ticket where extract(year from tic_date) = 2016 group by idclient order by sum(tic_totalttc) asc;
select idclient, sum(tic_totalttc) from entete_ticket where extract(year from tic_date) = 2017 group by idclient order by sum(tic_totalttc) asc;

--c. Répartition par âge x sexe
select age, count(civilite) from client where civilite = 'Monsieur' group by age;
select age, count(civilite) from client where civilite = 'Madame' group by age;
select age, count(civilite) from client where civilite = 'Monsieur' and age between 0 and 100 group by age;
select age, count(civilite) from client where civilite = 'Madame' and age between 0 and 100 group by age;

--2. Etude par magasin

--a. Résultat par magasin
drop table IF EXISTS resultat_magasin;
create table resultat_magasin 
( 
	MAGASIN varchar(15) primary key,
	NB_CLIENT_MAGASIN integer,
	NB_CLIENT_ACTIF_N2 bigint,
	NB_CLIENT_ACTIF_N1 bigint,
	POURCENTAGE_CLIENT char(3),
	TOTAL_TTC_N2 varchar(15),
	TOTAL_TTC_N1 varchar(15),
	DIFF_N1_N2 char(3),
	IND_EVOLUTION char(3)
);

insert into resultat_magasin(MAGASIN, NB_CLIENT_MAGASIN,NB_CLIENT_ACTIF_N2,NB_CLIENT_ACTIF_N1) (select magasin from client group by magasin order by magasin, select count(client.idclient) from client group by client.magasin order by client.magasin,
																							   select count(date(datefinadhesion)) from client where date(datefinadhesion) > '20180101'
and extract(year from datedebutadhesion) = 2016 group by magasin order by magasin, select count(date(datefinadhesion)) from client where date(datefinadhesion) > '20180101'
and extract(year from datedebutadhesion) = 2017 group by magasin order by magasin;);

UPDATE resultat_magasin SET POURCENTAGE_CLIENT = (case 
				when (NB_CLIENT_ACTIF_N2/NB_CLIENT_MAGASIN)-(NB_CLIENT_ACTIF_N1/NB_CLIENT_MAGASIN) >= 0 then 'pos'
				else 'neg'
end);

UPDATE resultat_magasin SET TOTAL_TTC_N2 = sum(tic_totalttc) from client
join entete_ticket on client.idclient = entete_ticket.idclient
where extract(year from tic_date) = 2016 group by magasin;

UPDATE resultat_magasin SET TOTAL_TTC_N1 = sum(tic_totalttc) from client
join entete_ticket on client.idclient = entete_ticket.idclient
where extract(year from tic_date) = 2017 group by magasin;

UPDATE resultat_magasin SET DIFF_N1_N2 = (case 
				when TOTAL_TTC_N2 - TOTAL_TTC_N1 >= 0 then 'pos'
				else 'neg'
end);

UPDATE resultat_magasin SET IND_EVOLUTION = (case 
				when POURCENTAGE_CLIENT = 'pos' and DIFF_N1_N2 = 'pos' then 'pos'
				when POURCENTAGE_CLIENT = 'neg' and DIFF_N1_N2 = 'neg' then 'neg'
				else 'moy'
end);

--b. Distance client/magasin
drop table IF EXISTS donnees_GPS;
create table donnees_GPS 
( 
	CODEINSEE varchar(10),
	VILLE varchar(50),
	GEO_POINT_2D varchar(50)
);

COPY donnees_GPS  FROM 'C:\Users\Public\DATA_Projet_Transverse\correspondance-code-insee-code-postal.CSV' CSV HEADER delimiter ';' null '';

ALTER TABLE donnees_GPS ADD LATITUDE real;
UPDATE donnees_GPS SET LATITUDE = cast(split_part(geo_point_2d,',',1) as real);
ALTER TABLE donnees_GPS ADD LONGITUDE real;
UPDATE donnees_GPS SET LONGITUDE = cast(split_part(geo_point_2d,',',2) as real);

ALTER TABLE client ADD LATITUDE real;
UPDATE client SET LATITUDE = donnees_gps.latitude from donnees_gps where client.codeinsee = donnees_gps.codeinsee;
ALTER TABLE client ADD LONGITUDE real;
UPDATE client SET LONGITUDE = donnees_gps.longitude from donnees_gps where client.codeinsee = donnees_gps.codeinsee;

ALTER TABLE ref_magasin ADD LATITUDE real;
UPDATE donnees_gps SET ville =  REPLACE(ville , '-', ' ');
UPDATE ref_magasin SET ville =  REPLACE(ville , 'ST', 'SAINT');
UPDATE ref_magasin SET ville =  REPLACE(ville , ' CEDEX', '');
UPDATE ref_magasin SET LATITUDE = donnees_GPS.latitude from donnees_gps where ref_magasin.ville = donnees_gps.ville;
ALTER TABLE ref_magasin ADD LONGITUDE real;
UPDATE ref_magasin SET LONGITUDE = donnees_GPS.longitude from donnees_gps where ref_magasin.ville = donnees_gps.ville;

CREATE FUNCTION distance_entre_2_points(latitude1 real, longitude1 real, latitude2 real, longitude2 real)
returns real
as
'
	Declare d real;
	begin
		d = 6371*acos(sin(radians(latitude1))*sin(radians(latitude2))+cos(radians(latitude1))*cos(radians(latitude2))*cos(radians(longitude2-longitude1)));
		return d;
	end;
'
LANGUAGE PLPGSQL

--3. Etude par univers

--a. ETUDE PAR UNIVERS
select codeunivers, sum(tic_totalttc) from entete_ticket join lignes_ticket on entete_ticket.idticket = lignes_ticket.idticket
join ref_article on lignes_ticket.idarticle = codearticle where extract(year from tic_date) = 2016 group by codeunivers;

select codeunivers, sum(tic_totalttc) from entete_ticket join lignes_ticket on entete_ticket.idticket = lignes_ticket.idticket
join ref_article on lignes_ticket.idarticle = codearticle where extract(year from tic_date) = 2017 group by codeunivers;

--b. TOP PAR UNIVERS
select sum(margesortie), codefamille from ref_article
join lignes_ticket on lignes_ticket.idarticle = codearticle where ref_article.codeunivers = 'U0' group by codefamille order by sum(margesortie) desc limit 5;

select sum(margesortie), codefamille from ref_article
join lignes_ticket on lignes_ticket.idarticle = codearticle where ref_article.codeunivers = 'U1' group by codefamille order by sum(margesortie) desc limit 5;

select sum(margesortie), codefamille from ref_article
join lignes_ticket on lignes_ticket.idarticle = codearticle where ref_article.codeunivers = 'U2' group by codefamille order by sum(margesortie) desc limit 5;

select sum(margesortie), codefamille from ref_article
join lignes_ticket on lignes_ticket.idarticle = codearticle where ref_article.codeunivers = 'U3' group by codefamille order by sum(margesortie) desc limit 5;

select sum(margesortie), codefamille from ref_article
join lignes_ticket on lignes_ticket.idarticle = codearticle where ref_article.codeunivers = 'U4' group by codefamille order by sum(margesortie) desc limit 5;