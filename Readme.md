## Database schema creation

Create a database schema to hold the following information:

**Authors:**
```
"name", "country"
"J. D. Salinger", "US"
"F. Scott. Fitzgerald", "US"
"Jane Austen", "UK"
"Leo Tolstoy", "RU"
"Sun Tzu", "CN"
"Johann Wolfgang von Goethe", "DE"
"Janis Eglitis", "LV"
```

**Books:**
```
"name", "author", "pages"
"The Catcher in the Rye", "J. D. Salinger", 300
"Nine Stories", "J. D. Salinger", 200
"Franny and Zooey", "J. D. Salinger", 150
"The Great Gatsby", "F. Scott. Fitzgerald", 400
"Tender is the Night", "F. Scott. Fitzgerald", 500
"Pride and Prejudice", "Jane Austen", 700
"The Art of War", "Sun Tzu", 128
"Faust I", "Johann Wolfgang von Goethe", 300
"Faust II", "Johann Wolfgang von Goethe", 300
```

Provide the schema and content for Postgres 9.6 or higher, including instructions on how to import it into a local 
database.

### Dump file
See `dump.sql` file. It was created with pg_dump command.

### Instructions to import dump
- You need PostgreSQL installed or Docker container started (provided in this repository).
- Make sure you are in the same folder, where dump file is.
- On the local machine run commands
`su - postgres` to act as root  
`createuser --interactive --pwprompt` to create user. Follow the instructions.    
 Then run `psql -U <new_user_name> -W -d database_name_dump < dump.sql` where `<new_user_name>` is role from previous 
 command.  
It will create `books_authors` DB with both schema and insertions.  
You don't need to create user in Docker container provider there, as it already has one:
- Just run `docker-compose build` to build an image. 
- Then `docker-compose up -d`  to run new container. 
- Finally, `docker-compose exec postgresql /bin/bash` to enter container. From this point just follow instructions 
above of how to use dump.sql.
**Note: PostgreSQL container takes some time to start, so please be patient.**
  
## Produce queries to answer the following questions

- Find author by name "Leo"

- Find books of author "Fitzgerald"

- Find authors without books

- Count books per country

- Count average book length (in pages) per author


### Queries
** It took about and hour and a half to create Docker container, write all queries to fill data, experiment with some of
 them (did not use DBMS there)**

#### Find author by name "Leo"
```
SELECT *
FROM authors
WHERE name LIKE '%Leo%'
LIMIT 1;
```

#### Find books of author "Fitzgerald"
```
SELECT *
FROM books
WHERE author LIKE '%Fitzgerald%';
```


#### Find authors without books
```
SELECT a.*
FROM authors AS a
         LEFT JOIN books AS b
                   ON a.name = b.author
WHERE b.name IS NULL;
```


#### Count books per country
```
SELECT a.country, count(b.name) AS total_books
FROM books AS b
         RIGHT JOIN authors AS a
                    ON a.name = b.author
GROUP BY a.country;
```


#### Count average book length (in pages) per author
```
SELECT a.name, round(AVG(COALESCE(b.pages, 0))) AS avg_pages
FROM books AS b
         RIGHT JOIN authors AS a
                    ON a.name = b.author
GROUP BY a.name;
```


## Analyze and explain the time complexity of the queries

Include potential suggestions on how to improve it.
Consider that there might be millions of authors with millions of books.

### Results of analyze
**Well, this one took much longer :). I spent 3-4 hours running queries, describing them and analyzing ways to optimize
queries. Ways of optimisation are obvious, though. Most complex there was writing down description for each query and 
how I suggest improving them.** 


#### Terms explanation
Planning time - time it took to generate the query plan from the parsed query and optimize it. It does not include 
parsing or rewriting.  
Execution time - includes executor start-up and shut-down time, as well as the time to run any triggers that are fired, 
but it does not include parsing, rewriting, or planning time.  
(from official docs).  
We will operate with Execution time only for simplicity.

#### Find author by name "Leo"
Running original query we shall receive something like this:
```
Limit  (cost=0.00..1.09 rows=1 width=528) (actual time=0.027..0.040 rows=1 loops=1)
  ->  Seq Scan on authors  (cost=0.00..1.09 rows=1 width=528) (actual time=0.013..0.020 rows=1 loops=1)
        Filter: ((name)::text ~~ '%Leo%'::text)
        Rows Removed by Filter: 3
Planning time: 0.058 ms
Execution time: 0.099 ms
```
PostgreSQL engine runs sequential search by each row until first match (Limit). As we see, Filter passed first three 
records.  
Simple and fast query. Nevertheless, it's not efficient on a huge amount of records, as we need to go through each of 
them and search for this keyword. What we can do to improve, is to add full text index to this table:
```
ALTER TABLE authors ADD tokens TSVECTOR;
UPDATE authors a1
SET tokens = to_tsvector(a1.name)
FROM authors a2;

UPDATE authors a1
SET tokens = to_tsvector(a1.name)
FROM authors a2;

CREATE INDEX ts_tokens_index ON authors USING GIN (tokens);
```
Then we got something like this:
```
Limit  (cost=0.00..2.84 rows=1 width=528) (actual time=0.044..0.060 rows=1 loops=1)
  ->  Seq Scan on authors  (cost=0.00..2.84 rows=1 width=528) (actual time=0.029..0.037 rows=1 loops=1)
        Filter: (tokens @@ to_tsquery('Leo'::text))
        Rows Removed by Filter: 3
Planning time: 0.153 ms
Execution time: 0.120 ms
```
As you see, we got `Filter: (tokens @@ to_tsquery('Leo'::text))`. So now we use full text search.  
We got more strict search by exact name (better from business value perspective). With such a low quantity of
records engine uses Seq Scan by default. That is because of such a small amount of records it's more efficient to go 
block by block. Engine is smart enough and almost always chooses optimal way.  
Adding index allows us to speed up queries on a big amount of data.  
Switching off `SET enable_seqscan TO off;` shows us:
```
Limit  (cost=8.25..12.51 rows=1 width=528) (actual time=0.052..0.065 rows=1 loops=1)
  ->  Bitmap Heap Scan on authors  (cost=8.25..12.51 rows=1 width=528) (actual time=0.037..0.044 rows=1 loops=1)
        Recheck Cond: (tokens @@ to_tsquery('Leo'::text))
        Heap Blocks: exact=1
        ->  Bitmap Index Scan on ts_name_index  (cost=0.00..8.25 rows=1 width=0) (actual time=0.018..0.025 rows=1 loops=1)
              Index Cond: (tokens @@ to_tsquery('Leo'::text))
Planning time: 0.101 ms
Execution time: 0.143 ms
```
Query then becomes more complicated. Fist goes Bitmap Index Scan by Leo (in index). Then Bitmap Heap Scan actually 
fetches those rows from the table itself. And finally there goes Limit operation. For those amount of data, Execution 
time is pretty much the same for all versions.
  
  
#### Find books of author "Fitzgerald"
Original analysis shows us:
```
Seq Scan on books  (cost=0.00..1.11 rows=1 width=1068) (actual time=0.031..0.142 rows=2 loops=1)
  Filter: ((author)::text ~~ '%Fitzgerald%'::text)
  Rows Removed by Filter: 7
Planning time: 0.066 ms
Execution time: 0.218 ms
```
As you see, `Rows Removed by Filter: 7`. We did not use LIMIT. That means, that engine must simply go through each line 
and check for `Fitzgerald`.  
There is the same approach to speed up with full text search on bigger quantity of records:
```
ALTER TABLE books ADD tokens TSVECTOR;

UPDATE books b1
SET tokens = to_tsvector(b1.author)
FROM books b2;

CREATE INDEX ts_author_index ON books USING GIN (tokens);
```
Then, change query to:
```
EXPLAIN ANALYZE SELECT *
FROM books
WHERE tokens @@ to_tsquery('Fitzgerald');
```
You will get something like this:
```
Seq Scan on books  (cost=0.00..3.36 rows=1 width=1068) (actual time=0.032..0.068 rows=2 loops=1)
  Filter: (tokens @@ to_tsquery('Fitzgerald'::text))
  Rows Removed by Filter: 7
Planning time: 0.108 ms
Execution time: 0.121 ms
```
Still, simple sequential scan is cheaper, that using indexes. But Execution time decreased.  
Filter has changed to full text search: `Filter: (tokens @@ to_tsquery('Fitzgerald'::text))`.  
Switching off `SET enable_seqscan TO off;` shows us:
```
Bitmap Heap Scan on books  (cost=8.25..12.51 rows=1 width=1068) (actual time=0.035..0.056 rows=2 loops=1)
  Recheck Cond: (tokens @@ to_tsquery('Fitzgerald'::text))
  Heap Blocks: exact=1
  ->  Bitmap Index Scan on ts_author_index  (cost=0.00..8.25 rows=1 width=0) (actual time=0.016..0.024 rows=2 loops=1)
        Index Cond: (tokens @@ to_tsquery('Fitzgerald'::text))
Planning time: 0.097 ms
Execution time: 0.136 ms
```
Final result is pretty much the same as in the previous query, except that we don't use Limit operation. And it is more 
expensive than without index.


#### Find authors without books
Let's analyze original queue:
```
Hash Right Join  (cost=1.16..2.35 rows=1 width=560) (actual time=0.338..0.362 rows=2 loops=1)
  Hash Cond: ((b.author)::text = (a.name)::text)
  Filter: (b.name IS NULL)
  Rows Removed by Filter: 9
  ->  Seq Scan on books b  (cost=0.00..1.09 rows=9 width=1032) (actual time=0.012..0.089 rows=9 loops=1)
  ->  Hash  (cost=1.07..1.07 rows=7 width=560) (actual time=0.147..0.154 rows=7 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 9kB
        ->  Seq Scan on authors a  (cost=0.00..1.07 rows=7 width=560) (actual time=0.014..0.075 rows=7 loops=1)
Planning time: 0.148 ms
Execution time: 0.483 ms
```
So engine first goes through authors table (Seq Scan). It creates hash (9kB of memory used) for each authors table row. 
Then engine goes through books table, and creates hash for each row there. Then we have this Hash Right Join (comparison 
of two hashes) operation with filter (Rows Removed by Filter: 9).  
To improve search, we can add index for authors.name and books.author columns. That will help engine a lot on fatter 
table.
```
CREATE INDEX authors_name_index
    ON authors (name);
CREATE INDEX books_author_index
    ON books (author);
```
I got:
```
Merge Left Join  (cost=0.27..24.62 rows=1 width=560) (actual time=0.273..0.400 rows=2 loops=1)
  Merge Cond: ((a.name)::text = (b.author)::text)
  Filter: (b.name IS NULL)
  Rows Removed by Filter: 9
  ->  Index Scan using authors_name_index on authors a  (cost=0.13..12.24 rows=7 width=560) (actual time=0.026..0.086 rows=7 loops=1)
  ->  Index Scan using books_author_index on books b  (cost=0.14..12.27 rows=9 width=1032) (actual time=0.007..0.158 rows=9 loops=1)
Planning time: 0.112 ms
Execution time: 0.486 ms
```
This result was get by using `SET enable_seqscan TO off;` command before execution of query. By default engine used 
old approach, as it is more efficient for this amount of rows. It's cheaper to go through each line than use index 
instead.  
So engine scan both indexes. Then it does Merge Left Join with filter (Filter: (b.name IS NULL)). As we can see, cost
increased, but execution time is almost the same. Again, this will help on a huge amount of data. And there are less 
nodes of operations needed.

#### Count average book length (in pages) per author
Let's analyze original queue:
```
HashAggregate  (cost=2.40..2.47 rows=7 width=20) (actual time=0.552..0.614 rows=6 loops=1)
  Group Key: a.country
  ->  Hash Right Join  (cost=1.16..2.35 rows=9 width=528) (actual time=0.207..0.436 rows=11 loops=1)
        Hash Cond: ((b.author)::text = (a.name)::text)
        ->  Seq Scan on books b  (cost=0.00..1.09 rows=9 width=1032) (actual time=0.023..0.097 rows=9 loops=1)
        ->  Hash  (cost=1.07..1.07 rows=7 width=528) (actual time=0.142..0.149 rows=7 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              ->  Seq Scan on authors a  (cost=0.00..1.07 rows=7 width=528) (actual time=0.017..0.079 rows=7 loops=1)
Planning time: 0.126 ms
Execution time: 0.875 ms
```
Engine goes through authors table. Then create hash for each row and does Seq Scan on books and matching both hashes 
with Hash Right Join. Finally, we can do a HashAggregate operation.  
Using indexes we already created, we got:
```
GroupAggregate  (cost=24.76..24.90 rows=7 width=20) (actual time=0.638..0.952 rows=6 loops=1)
  Group Key: a.country
  ->  Sort  (cost=24.76..24.78 rows=9 width=528) (actual time=0.588..0.729 rows=11 loops=1)
        Sort Key: a.country
        Sort Method: quicksort  Memory: 25kB
        ->  Merge Left Join  (cost=0.27..24.62 rows=9 width=528) (actual time=0.063..0.494 rows=11 loops=1)
              Merge Cond: ((a.name)::text = (b.author)::text)
              ->  Index Scan using authors_name_index on authors a  (cost=0.13..12.24 rows=7 width=528) (actual time=0.019..0.080 rows=7 loops=1)
              ->  Index Scan using books_author_index on books b  (cost=0.14..12.27 rows=9 width=1032) (actual time=0.013..0.092 rows=9 loops=1)
Planning time: 0.120 ms
Execution time: 1.178 ms
```
Engine Scan both indexes. Then executes Merge Left Join. Next step is to do a Sort by the country field. There goes 
a GroupAggregate function finally.
Execution time increased, as we use Indexes. Engine was right when used sequential scan.
Because we use this count aggregation function, engine is constantly forced to calculate this aggregated field each time
we do this query. So we can create an aggregated field:
```
ALTER TABLE authors ADD total_books INT;

UPDATE authors a
SET    total_books = sub.total_books
FROM  (
    SELECT a.country, count(b.name) AS total_books
        FROM books AS b
            RIGHT JOIN authors AS a
                ON a.name = b.author
    GROUP BY a.country
   ) sub
WHERE a.country = sub.country;
```
So we will have column total_books filled with correct data. Query then transforms to:
```
SELECT country, total_books
FROM authors
GROUP BY a.country;
```
Explain and analyze:
```
EXPLAIN ANALYZE SELECT DISTINCT country, total_books
FROM authors;
```

I got:
```
Unique  (cost=10000000001.17..10000000001.22 rows=7 width=16) (actual time=0.165..0.327 rows=6 loops=1)
  ->  Sort  (cost=10000000001.17..10000000001.19 rows=7 width=16) (actual time=0.141..0.203 rows=7 loops=1)
        Sort Key: country, total_books
        Sort Method: quicksort  Memory: 25kB
        ->  Seq Scan on authors  (cost=10000000000.00..10000000001.07 rows=7 width=16) (actual time=0.013..0.073 rows=7 loops=1)
Planning time: 0.066 ms
Execution time: 0.442 ms
```
Execution time decreased a lot in comparison to previous query. We don't use Join, and it helps us a lot.  
So engine goes through authors. Then Sort them by Sort Key: country, total_books". A final step is to select unique 
records.  
At this moment we see, that we have two records with country US and there total_books is duplicated. There normalization
should step in. To reduce data duplication, we can create table countries. The aggregated column will migrate to this new 
table then. And query will be significantly simplified to: 
```
SELECT country, total_books
FROM countries;
```

#### Count average book length (in pages) per author
Let's analyze original queue:
```
EXPLAIN ANALYZE SELECT a.name, round(AVG(COALESCE(b.pages, 0))) AS avg_pages
FROM books AS b
         RIGHT JOIN authors AS a
                    ON a.name = b.author
GROUP BY a.name;
```

I got:
```
GroupAggregate  (cost=12.55..24.93 rows=7 width=548) (actual time=0.384..0.781 rows=7 loops=1)
  Group Key: a.name
  ->  Merge Left Join  (cost=12.55..24.78 rows=9 width=520) (actual time=0.214..0.548 rows=11 loops=1)
        Merge Cond: ((a.name)::text = (b.author)::text)
        ->  Index Only Scan using authors_pkey on authors a  (cost=0.13..12.24 rows=7 width=516) (actual time=0.017..0.080 rows=7 loops=1)
              Heap Fetches: 7
        ->  Sort  (cost=12.41..12.44 rows=9 width=520) (actual time=0.173..0.247 rows=9 loops=1)
              Sort Key: b.author
              Sort Method: quicksort  Memory: 25kB
              ->  Index Scan using books_author_index on books b  (cost=0.14..12.27 rows=9 width=520) (actual time=0.012..0.089 rows=9 loops=1)
Planning time: 0.137 ms
Execution time: 0.949 ms
```
There is the first time then Index Scan step in by engine suggestion. In the beginning, Engine analyse books. Then make 
Sort by Sort Key: books.author and Index Only Scan on authors table. Next step is to Merge Left Join. And finally there 
is GroupAggregate operation by Group Key: a.name.
Approach for optimisation there is the same as in previous case:
```
ALTER TABLE authors ADD avg_pages INT;

UPDATE authors a
SET    avg_pages = sub.avg_pages
FROM  (
    SELECT a.name, round(AVG(COALESCE(b.pages, 0))) AS avg_pages
    FROM books AS b
             RIGHT JOIN authors AS a
                        ON a.name = b.author
    GROUP BY a.name
   ) sub
WHERE a.name = sub.name;
```
Adding aggregated column to authors table simplifies our query to the simplest:
```
SELECT name, avg_pages
FROM authors;
```
Run explain
```
EXPLAIN ANALYZE SELECT name, avg_pages
FROM authors;
```
and we got:
```
Seq Scan on authors  (cost=10000000000.00..10000000001.07 rows=7 width=520) (actual time=0.018..0.076 rows=7 loops=1)
Planning time: 0.046 ms
Execution time: 0.168 ms
```

So there is the simplest single operation Seq Scan on authors. Execution time is very-very low, so we have a huge 
profit of this optimisation.
  
  
**P.S.**: I did not go with classical id fields with unique int values in this task. Tables should have them by default. We 
can have several complete namesakes in the list of authors. And even same named books by different authors. But I 
believe it is out of the range of this task and was not the target.  
Other than that, we can use indexes for aggregated functions like round(AVG(COALESCE(b.pages, 0))) or count(b.name), but
 it is not effective from practical reasons. Creating separate fields make this table more visual. Although, it 
 significantly decreases comptutations in future. We can only recalculate one row in case of any changes with books 
 quantity.