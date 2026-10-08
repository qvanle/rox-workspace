# QC brief (fill, then dispatch rox-workspace:qc)

Independence rule: this brief holds the requirement, the spec and the commit only. **Do not add** the executor's DONE block, its TESTS list,
its summary, or anything about how the work was built.

Project and task: <project> #<id>
Repo: <absolute repo path>
Spec: <repo-relative spec path>   (must carry "Status: approved ...")
Commit under test: <git rev-parse HEAD>   Tree: clean | dirty (<files>)
Test plan source: the "Test plan" section of the spec
Question: verify every R-id of the task against the spec's test plan; write the Review notes in the spec; return the qc return block.
