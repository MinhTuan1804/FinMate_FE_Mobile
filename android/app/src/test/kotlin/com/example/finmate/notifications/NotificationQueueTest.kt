package com.example.finmate.notifications

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class NotificationQueueTest {
    @get:Rule val tmp = TemporaryFolder()
    private lateinit var file: File

    @Before fun setUp() {
        file = File(tmp.root, "queue.json")
    }

    private fun item(id: String, at: Long = id.toLong()) =
        QueuedNotification(id, "pkg", "title $id", "body $id", at)

    @Test fun add_then_all_returns_oldest_first() {
        val q = NotificationQueue(file)
        q.add(item("1"))
        q.add(item("2"))
        assertEquals(listOf(item("1"), item("2")), q.all())
    }

    @Test fun add_beyond_max_drops_oldest() {
        val q = NotificationQueue(file, maxItems = 3)
        (1..4).forEach { q.add(item(it.toString())) }
        assertEquals(listOf("2", "3", "4"), q.all().map { it.id })
    }

    @Test fun remove_deletes_only_that_id() {
        val q = NotificationQueue(file)
        q.add(item("1"))
        q.add(item("2"))
        q.remove("1")
        assertEquals(listOf("2"), q.all().map { it.id })
    }

    @Test fun incrementAttempts_returns_new_count_and_persists() {
        val q = NotificationQueue(file)
        q.add(item("1"))
        assertEquals(1, q.incrementAttempts("1"))
        assertEquals(2, q.incrementAttempts("1"))
        assertEquals(2, NotificationQueue(file).all().single().attempts)
    }

    @Test fun corrupt_file_reads_as_empty_and_add_still_works() {
        file.writeText("{not json[")
        val q = NotificationQueue(file)
        assertTrue(q.all().isEmpty())
        q.add(item("1"))
        assertEquals(listOf("1"), q.all().map { it.id })
    }

    @Test fun survives_new_instance_on_same_file() {
        NotificationQueue(file).add(item("1"))
        assertEquals(listOf(item("1")), NotificationQueue(file).all())
    }

    @Test fun clear_empties_queue() {
        val q = NotificationQueue(file)
        q.add(item("1"))
        q.clear()
        assertTrue(q.all().isEmpty())
        assertTrue(NotificationQueue(file).all().isEmpty())
    }
}
