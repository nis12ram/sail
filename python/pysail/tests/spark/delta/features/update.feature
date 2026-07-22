@focus
Feature: Delta Lake Update

  Rule: Basic operations
    Background:
      Given variable location for temporary directory x
      Given final statement
        """
        DROP TABLE IF EXISTS delta_update_basic
        """
      Given statement template
        """
        CREATE TABLE delta_update_basic (
          id INT,
          name STRING,
          state STRING,
          department STRING,
          salary INT
        )
        USING DELTA LOCATION {{ location.sql }}
        """
      Given statement
        """
        INSERT INTO delta_update_basic
        SELECT * FROM VALUES
          (1, 'Alice', 'CA', 'Engineering', 75000),
          (2, 'Bob', 'TX', 'Marketing', 65000),
          (3, 'Charlie', 'NY', 'Engineering', 85000),
          (4, 'Diana', 'FL', 'Sales', 55000),
          (5, 'Eve', 'TX', 'Marketing', 70000),
          (6, 'Frank', 'CA', 'Engineering', 95000),
          (7, 'Grace', 'NY', 'Sales', 50000),
          (8, 'Henry', 'FL', 'HR', 60000)
        """

    Scenario: Update single column with WHERE clause
      Given statement
        """
        UPDATE delta_update_basic
        SET state = 'WA'
        WHERE department = 'Engineering'
        """
      Then delta log latest commit info contains
        | path                         | value                          |
        | operation                    | "UPDATE"                       |
        | operationParameters.predicate | "department = 'Engineering' " |
      When query
        """
        SELECT id, name, state, department, salary
        FROM delta_update_basic ORDER BY id
        """
      Then query result ordered
        | id | name    | state | department  | salary |
        | 1  | Alice   | WA    | Engineering | 75000  |
        | 2  | Bob     | TX    | Marketing   | 65000  |
        | 3  | Charlie | WA    | Engineering | 85000  |
        | 4  | Diana   | FL    | Sales       | 55000  |
        | 5  | Eve     | TX    | Marketing   | 70000  |
        | 6  | Frank   | WA    | Engineering | 95000  |
        | 7  | Grace   | NY    | Sales       | 50000  |
        | 8  | Henry   | FL    | HR          | 60000  |

    Scenario: Update multiple columns with WHERE clause
      Given statement
        """
        UPDATE delta_update_basic
        SET state = 'OR', salary = salary + 5000
        WHERE department = 'Marketing'
        """
      When query
        """
        SELECT id, name, state, department, salary
        FROM delta_update_basic ORDER BY id
        """
      Then query result ordered
        | id | name    | state | department  | salary |
        | 1  | Alice   | CA    | Engineering | 75000  |
        | 2  | Bob     | OR    | Marketing   | 70000  |
        | 3  | Charlie | NY    | Engineering | 85000  |
        | 4  | Diana   | FL    | Sales       | 55000  |
        | 5  | Eve     | OR    | Marketing   | 75000  |
        | 6  | Frank   | CA    | Engineering | 95000  |
        | 7  | Grace   | NY    | Sales       | 50000  |
        | 8  | Henry   | FL    | HR          | 60000  |

    Scenario: Update without WHERE clause updates all rows
      Given statement
        """
        UPDATE delta_update_basic SET state = 'ZZ'
        """
      When query
        """
        SELECT DISTINCT state as state FROM delta_update_basic
        """
      Then query result
        | state |
        | ZZ    |

    Scenario: Condition that matches no rows
      Given statement
        """
        UPDATE delta_update_basic
        SET state = 'XX'
        WHERE department = 'Astronomy'
        """
      When query
        """
        SELECT COUNT(*) as count FROM delta_update_basic WHERE state = 'XX'
        """
      Then query result
        | count |
        | 0     |

    Scenario: Update with complex expression in SET clause
      Given statement
        """
        UPDATE delta_update_basic
        SET name = lower(name)
        WHERE salary > 80000
        """
      When query
        """
        SELECT id, name, state, department, salary
        FROM delta_update_basic WHERE salary > 80000
        ORDER BY id
        """
      Then query result ordered
        | id | name    | state | department  | salary |
        | 3  | charlie | NY    | Engineering | 85000  |
        | 6  | frank   | CA    | Engineering | 95000  |

    Scenario: Update with complex conditions
      Given statement
        """
        UPDATE delta_update_basic
        SET state = 'WA'
        WHERE department = 'Engineering' AND id > 3
        """
      When query
        """
        SELECT id, name, state, department, salary
        FROM delta_update_basic ORDER BY id
        """
      Then query result ordered
        | id | name    | state | department  | salary |
        | 1  | Alice   | CA    | Engineering | 75000  |
        | 2  | Bob     | TX    | Marketing   | 65000  |
        | 3  | Charlie | NY    | Engineering | 85000  |
        | 4  | Diana   | FL    | Sales       | 55000  |
        | 5  | Eve     | TX    | Marketing   | 70000  |
        | 6  | Frank   | WA    | Engineering | 95000  |
        | 7  | Grace   | NY    | Sales       | 50000  |
        | 8  | Henry   | FL    | HR          | 60000  |

  Rule: Operations on partitioned tables
    Background:
      Given variable location for temporary directory y
      Given final statement
        """
        DROP TABLE IF EXISTS delta_update_partitioned
        """
      Given statement template
        """
        CREATE TABLE delta_update_partitioned (
          id INT,
          name STRING,
          year INT,
          month INT,
          value INT
        )
        USING DELTA LOCATION {{ location.sql }}
        PARTITIONED BY (year, month)
        """
      Given statement
        """
        INSERT INTO delta_update_partitioned
        SELECT * FROM VALUES
          (1, 'Alice', 2023, 1, 100),
          (2, 'Bob', 2023, 1, 200),
          (3, 'Charlie', 2023, 2, 300),
          (4, 'Diana', 2023, 2, 400),
          (5, 'Eve', 2024, 1, 500),
          (6, 'Frank', 2024, 1, 600),
          (7, 'Grace', 2024, 2, 700),
          (8, 'Henry', 2024, 2, 800)
        """

    Scenario: Update on partitioned table with partition-only predicate
      Given statement
        """
        UPDATE delta_update_partitioned
        SET value = value + 1000
        WHERE year = 2023
        """
      When query
        """
        SELECT id, name, year, month, value
        FROM delta_update_partitioned ORDER BY id
        """
      Then query result ordered
        | id | name    | year | month | value |
        | 1  | Alice   | 2023 | 1     | 1100  |
        | 2  | Bob     | 2023 | 1     | 1200  |
        | 3  | Charlie | 2023 | 2     | 1300  |
        | 4  | Diana   | 2023 | 2     | 1400  |
        | 5  | Eve     | 2024 | 1     | 500   |
        | 6  | Frank   | 2024 | 1     | 600   |
        | 7  | Grace   | 2024 | 2     | 700   |
        | 8  | Henry   | 2024 | 2     | 800   |

    Scenario: Update on partitioned table with mixed predicate
      Given statement
        """
        UPDATE delta_update_partitioned
        SET name = 'UPDATED', value = value * 10
        WHERE year = 2024 AND value > 550
        """
      When query
        """
        SELECT id, name, year, month, value
        FROM delta_update_partitioned ORDER BY id
        """
      Then query result ordered
        | id | name    | year | month | value |
        | 1  | Alice   | 2023 | 1     | 100   |
        | 2  | Bob     | 2023 | 1     | 200   |
        | 3  | Charlie | 2023 | 2     | 300   |
        | 4  | Diana   | 2023 | 2     | 400   |
        | 5  | Eve     | 2024 | 1     | 500   |
        | 6  | UPDATED   | 2024 | 1     | 6000  |
        | 7  | UPDATED   | 2024 | 2     | 7000  |
        | 8  | UPDATED   | 2024 | 2     | 8000  |


  Rule: Operations with potential conflicts
    Background:
      Given variable location for temporary directory z
      Given final statement
        """
        DROP TABLE IF EXISTS delta_update_conflict
        """
      Given statement template
        """
        CREATE TABLE delta_update_conflict (
          id INT,
          code STRING,
          amount INT
        )
        USING DELTA LOCATION {{ location.sql }}
        """
      Given statement
        """
        INSERT INTO delta_update_conflict
        SELECT * FROM VALUES
          (1, 'A', 100),
          (2, 'B', 200),
          (3, 'A', 300),
          (4, 'C', 400)
        """

    Scenario: Repeated column in SET clause raises error
      When query
        """
        UPDATE delta_update_conflict
        SET code = 'X', code = 'Y'
        WHERE id = 1
        """
      Then query error conflicting assignments found for SET column `code`

  Rule: Operations with null values
    Background:
      Given variable location for temporary directory w
      Given final statement
        """
        DROP TABLE IF EXISTS delta_update_null
        """
      Given statement template
        """
        CREATE TABLE delta_update_null (
          id INT,
          name STRING,
          department STRING
        )
        USING DELTA LOCATION {{ location.sql }}
        """
      Given statement
        """
        INSERT INTO delta_update_null
        SELECT * FROM VALUES
          (1, 'Alice', 'Engineering'),
          (2, 'Bob', NULL),
          (3, NULL, 'Marketing'),
          (4, 'Diana', 'Sales'),
          (5, NULL, NULL)
        """

    Scenario: Update rows matching null predicate
      Given statement
        """
        UPDATE delta_update_null
        SET department = 'UPDATED'
        WHERE department IS NULL
        """
      When query
        """
        SELECT id, name, department FROM delta_update_null ORDER BY id
        """
      Then query result ordered
        | id | name  | department  |
        | 1  | Alice | Engineering |
        | 2  | Bob   | UPDATED     |
        | 3  | NULL  | Marketing   |
        | 4  | Diana | Sales       |
        | 5  | NULL  | UPDATED     |
