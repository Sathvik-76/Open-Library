#!/usr/bin/env python3
# Candy Selling Optimization
# Author: ChatGPT demo – O(n) solution

import sys
from collections import deque

sys.setrecursionlimit(1 << 25)

def max_revenue(n, B, P):
    # Convert B to 0-based indices
    B = [b - 1 for b in B]

    indeg = [0] * n
    for i in range(n):
        if B[i] != i:
            indeg[B[i]] += 1

    q = deque(i for i in range(n) if indeg[i] == 0)
    sold = [False] * n
    revenue = 0

    # Step 1: Process tree-like dependencies (non-cycles)
    while q:
        u = q.popleft()
        revenue += 2 * P[u] if not sold[B[u]] else P[u]
        sold[u] = True

        v = B[u]
        if v != u:
            indeg[v] -= 1
            if indeg[v] == 0:
                q.append(v)

    # Step 2: Handle cycles
    visited = [False] * n
    for i in range(n):
        if sold[i] or visited[i]:
            continue

        cycle = []
        cur = i
        while not visited[cur]:
            visited[cur] = True
            cycle.append(cur)
            cur = B[cur]

        # Sell the minimum-priced candy last in the cycle
        min_node = min(cycle, key=lambda x: P[x])
        cur = B[min_node]
        while cur != min_node:
            revenue += 2 * P[cur]
            sold[cur] = True
            cur = B[cur]

        revenue += P[min_node]
        sold[min_node] = True

    return revenue

def main():
    data = sys.stdin.read().strip().split()
    if not data:
        return
    n = int(data[0])
    B = list(map(int, data[1:1 + n]))
    P = list(map(int, data[1 + n:1 + 2 * n]))
    print(max_revenue(n, B, P))

if __name__ == "__main__":
    main()
