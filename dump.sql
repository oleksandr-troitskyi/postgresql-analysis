--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.19
-- Dumped by pg_dump version 9.6.19

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: books_authors; Type: DATABASE; Schema: -; Owner: -
--

CREATE DATABASE books_authors WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.utf8' LC_CTYPE = 'en_US.utf8';


\connect books_authors

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: authors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.authors (
    name character varying(255) NOT NULL,
    country character varying(2) NOT NULL
);


--
-- Name: books; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.books (
    name character varying(255) NOT NULL,
    author character varying(255) NOT NULL,
    pages integer NOT NULL
);


--
-- Data for Name: authors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.authors (name, country) VALUES ('J. D. Salinger', 'US');
INSERT INTO public.authors (name, country) VALUES ('F. Scott. Fitzgerald', 'US');
INSERT INTO public.authors (name, country) VALUES ('Jane Austen', 'UK');
INSERT INTO public.authors (name, country) VALUES ('Leo Tolstoy', 'RU');
INSERT INTO public.authors (name, country) VALUES ('Sun Tzu', 'CN');
INSERT INTO public.authors (name, country) VALUES ('Johann Wolfgang von Goethe', 'DE');
INSERT INTO public.authors (name, country) VALUES ('Janis Eglitis', 'LV');


--
-- Data for Name: books; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.books (name, author, pages) VALUES ('The Catcher in the Rye', 'J. D. Salinger', 300);
INSERT INTO public.books (name, author, pages) VALUES ('Nine Stories', 'J. D. Salinger', 200);
INSERT INTO public.books (name, author, pages) VALUES ('Franny and Zooey', 'J. D. Salinger', 150);
INSERT INTO public.books (name, author, pages) VALUES ('The Great Gatsby', 'F. Scott. Fitzgerald', 400);
INSERT INTO public.books (name, author, pages) VALUES ('Tender is the Night', 'F. Scott. Fitzgerald', 500);
INSERT INTO public.books (name, author, pages) VALUES ('Pride and Prejudice', 'Jane Austen', 700);
INSERT INTO public.books (name, author, pages) VALUES ('The Art of War', 'Sun Tzu', 128);
INSERT INTO public.books (name, author, pages) VALUES ('Faust I', 'Johann Wolfgang von Goethe', 300);
INSERT INTO public.books (name, author, pages) VALUES ('Faust II', 'Johann Wolfgang von Goethe', 300);


--
-- Name: authors authors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authors
    ADD CONSTRAINT authors_pkey PRIMARY KEY (name);


--
-- Name: books books_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.books
    ADD CONSTRAINT books_pkey PRIMARY KEY (name);


--
-- Name: books fk_author; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.books
    ADD CONSTRAINT fk_author FOREIGN KEY (author) REFERENCES public.authors(name) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

