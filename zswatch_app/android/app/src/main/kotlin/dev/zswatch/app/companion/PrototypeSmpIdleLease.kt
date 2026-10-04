package dev.zswatch.app.companion

/** Keep the service's Nordic transport/SMP enabled across a short command burst.
 * An old UI command's idle cleanup cannot release a newer command or session.
 */
internal class PrototypeSmpIdleLease(
    private val later: (Long, () -> Unit) -> Unit,
    private val release: (Long) -> Unit,
) {
    private var generation: Long? = null
    private var epoch = 0L
    fun held(session: Long) = generation == session
    fun hold(session: Long) { generation = session; epoch++ }
    fun idle(session: Long) {
        if (generation != session) return
        val expected = ++epoch
        later(20000) {
            if (generation == session && epoch == expected) {
                generation = null
                release(session)
            }
        }
    }
    fun close() { generation = null; epoch++ }
}
