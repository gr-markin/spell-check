The original system deleted the tasks when there were no more views. In this
case, we want the plugin the manage the lifecycle of the task, not the views so
we removed this from the constructor.

    if Object.keys(@constructor.callbacksById).length is 0
      @constructor.task?.terminate()
      @constructor.task = null

* Change to be word-based searching.
* Plugins sending responses/changes to the task.
