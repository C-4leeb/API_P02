import psycopg2

def get_connection():
    return psycopg2.connect(
        dbname="proyecto 02",
        user="caleb",
        password="7741",
        host="localhost",
        port="5433"
    )
