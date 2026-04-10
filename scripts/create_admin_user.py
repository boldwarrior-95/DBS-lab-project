import hashlib

import oracledb as cx_Oracle


def main() -> None:
    dsn = cx_Oracle.makedsn("localhost", 1521, service_name="XE")
    conn = cx_Oracle.connect(user="dscae", password="dscae123", dsn=dsn)
    cur = conn.cursor()
    try:
        cur.execute("SELECT COUNT(*) FROM USERS WHERE username = :u", {"u": "admin"})
        exists = int(cur.fetchone()[0])
        if exists:
            print("User admin already exists; no changes made.")
            return

        pw_hash = hashlib.sha256("admin".encode()).hexdigest()
        cur.execute(
            "INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL,:un,:em,:pw,:br,:cg,:sem,'admin',SYSDATE)",
            {
                "un": "admin",
                "em": "admin@example.com",
                "pw": pw_hash,
                "br": "ADMIN",
                "cg": 10.0,
                "sem": "NA",
            },
        )
        conn.commit()
        print("Created user: admin (role=admin)")
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()

