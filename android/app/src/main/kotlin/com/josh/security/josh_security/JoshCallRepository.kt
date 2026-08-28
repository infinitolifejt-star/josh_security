package com.josh.security.josh_security

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

class JoshCallRepository(context: Context) :
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val TAG = "JOSH_DB"
        private const val DATABASE_NAME = "josh_security_calls.db"
        private const val DATABASE_VERSION = 1

        const val TABLE_CALLS = "calls_log"

        const val COLUMN_ID = "id"
        const val COLUMN_NUMBER = "number"
        const val COLUMN_NAME = "name"
        const val COLUMN_TIMESTAMP = "timestamp"
        const val COLUMN_TYPE = "type"
        const val COLUMN_STATUS = "status"
        const val COLUMN_RISK_SCORE = "risk_score"
        const val COLUMN_VERIFIED = "verified"
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTableQuery = """
            CREATE TABLE $TABLE_CALLS (
                $COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COLUMN_NUMBER TEXT NOT NULL,
                $COLUMN_NAME TEXT DEFAULT 'Desconocido',
                $COLUMN_TIMESTAMP INTEGER NOT NULL,
                $COLUMN_TYPE TEXT DEFAULT 'ENTRANTE',
                $COLUMN_STATUS TEXT NOT NULL,
                $COLUMN_RISK_SCORE REAL NOT NULL,
                $COLUMN_VERIFIED INTEGER DEFAULT 0
            )
        """.trimIndent()

        try {
            db.execSQL(createTableQuery)
            Log.d(TAG, "Tabla $TABLE_CALLS creada exitosamente.")
        } catch (e: Exception) {
            Log.e(TAG, "Error al crear la tabla $TABLE_CALLS: ${e.message}", e)
        }
    }

    override fun onUpgrade(
        db: SQLiteDatabase,
        oldVersion: Int,
        newVersion: Int
    ) {
        if (oldVersion < 2) {
            // Migraciones futuras manteniendo integridad del historial
        }
    }

    fun saveCall(
        number: String,
        name: String = "Desconocido",
        type: String = "ENTRANTE",
        status: String,
        riskScore: Double,
        isVerified: Boolean = false
    ): Long {
        val db = writableDatabase

        return try {
            val values = ContentValues().apply {
                put(COLUMN_NUMBER, number)
                put(COLUMN_NAME, name)
                put(COLUMN_TIMESTAMP, System.currentTimeMillis())
                put(COLUMN_TYPE, type)
                put(COLUMN_STATUS, status)
                put(COLUMN_RISK_SCORE, riskScore)
                put(COLUMN_VERIFIED, if (isVerified) 1 else 0)
            }

            val id = db.insert(TABLE_CALLS, null, values)

            Log.d(
                TAG,
                "saveCall() -> id=$id number=$number name=$name type=$type status=$status riskScore=$riskScore"
            )

            if (id == -1L) {
                Log.e(TAG, "ERROR: SQLite rechazo el INSERT en la tabla $TABLE_CALLS")
            }

            id
        } catch (e: Exception) {
            Log.e(TAG, "EXCEPCION guardando llamada: ${e.message}", e)
            -1L
        } finally {
            db.close()
        }
    }

    fun getAllCalls(): List<Map<String, Any>> {
        val callList = mutableListOf<Map<String, Any>>()
        val db = readableDatabase

        var cursor: android.database.Cursor? = null

        try {
            cursor = db.rawQuery(
                "SELECT * FROM $TABLE_CALLS ORDER BY $COLUMN_TIMESTAMP DESC",
                null
            )

            Log.d(TAG, "DB Path = ${db.path}")
            Log.d(TAG, "getAllCalls() -> Total registros encontrados en DB: ${cursor?.count ?: 0}")

            if (cursor != null && cursor.moveToFirst()) {
                do {
                    val item = mapOf(
                        "id" to cursor.getLong(cursor.getColumnIndexOrThrow(COLUMN_ID)),
                        "number" to (cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_NUMBER)) ?: ""),
                        "name" to (cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_NAME)) ?: "Desconocido"),
                        "timestamp" to cursor.getLong(cursor.getColumnIndexOrThrow(COLUMN_TIMESTAMP)),
                        "type" to (cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_TYPE)) ?: "ENTRANTE"),
                        "status" to (cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_STATUS)) ?: "SEGURO"),
                        "risk_score" to cursor.getDouble(cursor.getColumnIndexOrThrow(COLUMN_RISK_SCORE)),
                        "verified" to (cursor.getInt(cursor.getColumnIndexOrThrow(COLUMN_VERIFIED)) == 1)
                    )

                    callList.add(item)
                } while (cursor.moveToNext())
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error al ejecutar getAllCalls(): ${e.message}", e)
            throw e
        } finally {
            cursor?.close()
            db.close()
        }

        return callList
    }

    fun clearAllCalls(): Int {
        val db = writableDatabase

        return try {
            val rowsDeleted = db.delete(TABLE_CALLS, null, null)
            Log.d(TAG, "clearAllCalls() -> filas eliminadas: $rowsDeleted")
            rowsDeleted
        } catch (e: Exception) {
            Log.e(TAG, "Error al limpiar llamadas: ${e.message}", e)
            0
        } finally {
            db.close()
        }
    }
}
