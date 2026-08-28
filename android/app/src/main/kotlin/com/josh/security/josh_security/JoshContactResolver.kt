package com.josh.security.josh_security

import android.content.Context
import android.net.Uri
import android.provider.ContactsContract

object JoshContactResolver {

    fun resolveContactName(context: Context, phoneNumber: String): String {
        if (phoneNumber.isBlank() || phoneNumber == "Desconocido") return "Desconocido"

        var contactName = "Desconocido"
        val uri: Uri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
            Uri.encode(phoneNumber)
        )
        val projection = arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME)

        try {
            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(ContactsContract.PhoneLookup.DISPLAY_NAME)
                    if (nameIndex != -1) {
                        contactName = cursor.getString(nameIndex) ?: "Desconocido"
                    }
                }
            }
        } catch (e: Exception) {
            // Manejo silencioso si el usuario denegó READ_CONTACTS
        }

        return contactName
    }
}
