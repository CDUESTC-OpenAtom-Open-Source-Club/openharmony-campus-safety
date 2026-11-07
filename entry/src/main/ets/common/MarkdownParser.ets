// Plain data only: parsing never executes HTML, loads a resource, or opens a link.
export class MarkdownSpan {
  text: string = ''
  bold: boolean = false
  italic: boolean = false
  strike: boolean = false
  code: boolean = false
  url: string = ''
  image: boolean = false
}

export class MarkdownRow {
  cells: MarkdownSpan[][] = []
}

export class MarkdownBlock {
  kind: string = 'paragraph'
  text: string = ''
  level: number = 0
  marker: string = ''
  checked: number = -1
  spans: MarkdownSpan[] = []
  children: MarkdownBlock[] = []
  rows: MarkdownRow[] = []
  alignments: string[] = []
}

class MarkdownReference {
  url: string = ''
}

class MarkdownListMarker {
  indent: number = 0
  width: number = 0
  ordered: boolean = false
  number: number = 1
  content: string = ''
}

export class MarkdownParser {
  private references: Map<string, MarkdownReference> = new Map()
  private static readonly MAX_DEPTH: number = 16

  static parse(source: string): MarkdownBlock[] {
    const parser = new MarkdownParser()
    const lines = source.replace(/\r\n?/g, '\n').split('\n')
    // Reference definitions inside fenced code must stay literal.
    let fence: string = ''
    let fenceSize: number = 0
    for (let i = 0; i < lines.length; i++) {
      const match = /^ {0,3}(`{3,}|~{3,})(.*)$/.exec(lines[i])
      if (match !== null) {
        if (fence.length === 0) {
          fence = match[1][0]
          fenceSize = match[1].length
        } else if (match[1][0] === fence && match[1].length >= fenceSize && match[2].trim() === '') {
          fence = ''
        }
      }
      if (fence.length === 0) {
        const definition = /^ {0,3}\[([^\]^][^\]]*)\]:\s*<?([^\s>]+)>?(?:\s+["'(].*)?$/.exec(lines[i])
        if (definition !== null) {
          const reference = new MarkdownReference()
          reference.url = definition[2]
          parser.references.set(definition[1].trim().toLowerCase(), reference)
          lines[i] = ''
        }
      }
    }
    return parser.parseBlocks(lines, 0)
  }

  static safeUrl(value: string): string {
    // No javascript:, data:, local files, custom application schemes, or control characters.
    const url = value.trim()
    if (/[\u0000-\u0020\u007f]/.test(url)) {
      return ''
    }
    return /^https?:\/\/[^/\s?#]+(?:[/?#]|$)/i.test(url) ? url : ''
  }

  private textBlock(text: string, kind: string = 'paragraph'): MarkdownBlock {
    const block = new MarkdownBlock()
    block.kind = kind
    block.text = text
    block.spans = this.parseInline(text, 0)
    return block
  }

  private listMarker(line: string): MarkdownListMarker | undefined {
    const match = /^( *)([-+*]|\d{1,9}[.)]) +(.*)$/.exec(line)
    if (match === null) {
      return undefined
    }
    const marker = new MarkdownListMarker()
    marker.indent = match[1].length
    marker.ordered = /^\d/.test(match[2])
    marker.number = marker.ordered ? parseInt(match[2], 10) : 1
    marker.width = line.length - match[3].length
    marker.content = match[3]
    return marker
  }

  private isRule(line: string): boolean {
    return /^ {0,3}(?:(?:\*\s*){3,}|(?:-\s*){3,}|(?:_\s*){3,})$/.test(line)
  }

  private isBlockStart(lines: string[], index: number): boolean {
    const line = lines[index]
    return line.trim() === '' || /^ {0,3}(#{1,6})(?:\s|$)/.test(line) ||
      /^ {0,3}(`{3,}|~{3,})/.test(line) || /^ {0,3}>/.test(line) ||
      this.isRule(line) || this.listMarker(line) !== undefined ||
      (index + 1 < lines.length && this.tableAlignments(lines[index + 1]).length > 0 && line.includes('|'))
  }

  private parseBlocks(lines: string[], depth: number): MarkdownBlock[] {
    if (depth > MarkdownParser.MAX_DEPTH) {
      return [this.textBlock(lines.join('\n'))]
    }
    const blocks: MarkdownBlock[] = []
    let i = 0
    while (i < lines.length) {
      const line = lines[i]
      if (line.trim() === '') {
        i++
        continue
      }
      const fence = /^ {0,3}(`{3,}|~{3,})(.*)$/.exec(line)
      if (fence !== null) {
        const block = new MarkdownBlock()
        block.kind = 'code'
        block.marker = fence[2].trim().split(/\s/)[0]
        const code: string[] = []
        const openingIndent = line.length - line.trimStart().length
        i++
        while (i < lines.length) {
          const closing = /^ {0,3}(`{3,}|~{3,})\s*$/.exec(lines[i])
          if (closing !== null && closing[1][0] === fence[1][0] && closing[1].length >= fence[1].length) {
            i++
            break
          }
          code.push(lines[i].slice(Math.min(openingIndent, lines[i].length - lines[i].trimStart().length)))
          i++
        }
        block.text = code.join('\n')
        blocks.push(block)
        continue
      }
      const heading = /^ {0,3}(#{1,6})(?:[ \t]+(.*)|$)/.exec(line)
      if (heading !== null) {
        const block = this.textBlock((heading[2] || '').replace(/[ \t]+#+[ \t]*$/, '').trim(), 'heading')
        block.level = heading[1].length
        blocks.push(block)
        i++
        continue
      }
      if (!this.isRule(line) && this.listMarker(line) === undefined && !/^ {0,3}>/.test(line) &&
        i + 1 < lines.length && /^ {0,3}(=+|-+)\s*$/.test(lines[i + 1])) {
        const block = this.textBlock(line.trim(), 'heading')
        block.level = lines[i + 1].trim()[0] === '=' ? 1 : 2
        blocks.push(block)
        i += 2
        continue
      }
      if (this.isRule(line)) {
        const block = new MarkdownBlock()
        block.kind = 'rule'
        blocks.push(block)
        i++
        continue
      }
      if (/^ {0,3}>/.test(line)) {
        const quote: string[] = []
        while (i < lines.length && /^ {0,3}>/.test(lines[i])) {
          quote.push(lines[i].replace(/^ {0,3}> ?/, ''))
          i++
        }
        const block = new MarkdownBlock()
        block.kind = 'quote'
        block.children = this.parseBlocks(quote, depth + 1)
        blocks.push(block)
        continue
      }
      const firstMarker = this.listMarker(line)
      if (firstMarker !== undefined && firstMarker.indent < 4) {
        const list = new MarkdownBlock()
        list.kind = 'list'
        let number = firstMarker.number
        while (i < lines.length) {
          const marker = this.listMarker(lines[i])
          if (marker === undefined || marker.indent !== firstMarker.indent || marker.ordered !== firstMarker.ordered) {
            break
          }
          const item = new MarkdownBlock()
          item.kind = 'item'
          item.marker = marker.ordered ? `${number}.` : '•'
          number++
          const task = /^\[([ xX])\]\s+(.*)$/.exec(marker.content)
          item.checked = task === null ? -1 : (task[1] === ' ' ? 0 : 1)
          const content: string[] = [task === null ? marker.content : task[2]]
          i++
          while (i < lines.length) {
            if (lines[i].trim() === '') {
              let next = i + 1
              while (next < lines.length && lines[next].trim() === '') {
                next++
              }
              if (next < lines.length && lines[next].length - lines[next].trimStart().length >= marker.width) {
                content.push('')
                i++
                continue
              }
              i = next
              break
            }
            const indent = lines[i].length - lines[i].trimStart().length
            if (indent < marker.width) {
              // Unindented continuation belongs to the current paragraph only.
              if (!this.isBlockStart(lines, i)) {
                content.push(lines[i])
                i++
                continue
              }
              break
            }
            content.push(lines[i].slice(marker.width))
            i++
          }
          item.children = this.parseBlocks(content, depth + 1)
          list.children.push(item)
        }
        blocks.push(list)
        continue
      }
      if (i + 1 < lines.length && line.includes('|')) {
        const alignments = this.tableAlignments(lines[i + 1])
        const headers = this.tableCells(line)
        if (alignments.length > 0 && headers.length === alignments.length) {
          const block = new MarkdownBlock()
          block.kind = 'table'
          block.alignments = alignments
          block.rows.push(this.tableRow(headers, headers.length))
          i += 2
          while (i < lines.length && lines[i].trim() !== '' && lines[i].includes('|') &&
            !/^ {0,3}(>|#{1,6}\s|`{3,}|~{3,})/.test(lines[i])) {
            block.rows.push(this.tableRow(this.tableCells(lines[i]), headers.length))
            i++
          }
          blocks.push(block)
          continue
        }
      }
      if (/^ {4}/.test(line)) {
        const code: string[] = []
        while (i < lines.length && (/^ {4}/.test(lines[i]) || lines[i].trim() === '')) {
          code.push(lines[i].slice(4))
          i++
        }
        while (code.length > 0 && code[code.length - 1] === '') {
          code.pop()
        }
        const block = new MarkdownBlock()
        block.kind = 'code'
        block.text = code.join('\n')
        blocks.push(block)
        continue
      }
      const paragraph: string[] = [line]
      i++
      while (i < lines.length && !this.isBlockStart(lines, i)) {
        // Setext headings can span more than one line.
        if (/^ {0,3}(=+|-+)\s*$/.test(lines[i])) {
          break
        }
        paragraph.push(lines[i])
        i++
      }
      if (i < lines.length && /^ {0,3}(=+|-+)\s*$/.test(lines[i])) {
        const block = this.textBlock(paragraph.join('\n'), 'heading')
        block.level = lines[i].trim()[0] === '=' ? 1 : 2
        blocks.push(block)
        i++
      } else {
        blocks.push(this.textBlock(paragraph.join('\n')))
      }
    }
    return blocks
  }

  private tableCells(line: string): string[] {
    let source = line.trim()
    if (source.startsWith('|')) {
      source = source.slice(1)
    }
    if (source.endsWith('|') && !source.endsWith('\\|')) {
      source = source.slice(0, -1)
    }
    const cells: string[] = []
    let cell = ''
    let ticks = 0
    for (let i = 0; i < source.length; i++) {
      const ch = source[i]
      if (ch === '\\' && i + 1 < source.length) {
        cell += ch + source[++i]
      } else if (ch === '`') {
        let count = 1
        while (source[i + 1] === '`') {
          count++
          i++
        }
        ticks = ticks === count ? 0 : (ticks === 0 ? count : ticks)
        cell += '`'.repeat(count)
      } else if (ch === '|' && ticks === 0) {
        cells.push(cell.trim())
        cell = ''
      } else {
        cell += ch
      }
    }
    cells.push(cell.trim())
    return cells
  }

  private tableAlignments(line: string): string[] {
    const cells = this.tableCells(line)
    if (cells.length === 0 || !cells.every((cell: string) => /^:?-{3,}:?$/.test(cell))) {
      return []
    }
    return cells.map((cell: string) => cell.endsWith(':') ? (cell.startsWith(':') ? 'center' : 'right') : 'left')
  }

  private tableRow(cells: string[], width: number): MarkdownRow {
    const row = new MarkdownRow()
    for (let i = 0; i < width; i++) {
      row.cells.push(this.parseInline(i < cells.length ? cells[i] : '', 0))
    }
    return row
  }

  private decode(text: string): string {
    return text.replace(/&(?:amp|lt|gt|quot|apos|nbsp|#\d+|#x[0-9a-f]+);/gi, (entity: string): string => {
      switch (entity.toLowerCase()) {
        case '&amp;': return '&'
        case '&lt;': return '<'
        case '&gt;': return '>'
        case '&quot;': return '"'
        case '&apos;': return "'"
        case '&nbsp;': return '\u00a0'
        default:
          const hex = entity.slice(0, 3).toLowerCase() === '&#x'
          const value = parseInt(entity.slice(hex ? 3 : 2, -1), hex ? 16 : 10)
          return value > 0 && value <= 0x10ffff && !(value >= 0xd800 && value <= 0xdfff) ?
            String.fromCodePoint(value) : '\ufffd'
      }
    })
  }

  private closingDelimiter(text: string, delimiter: string, from: number): number {
    const stack: number[] = [delimiter.length]
    let index = from
    while (index < text.length) {
      if (text[index] === '\\') { index += 2; continue }
      // Emphasis markers inside an inline code span are literal.
      if (text[index] === '`') {
        let ticks = 1
        while (text[index + ticks] === '`') { ticks++ }
        const end = text.indexOf('`'.repeat(ticks), index + ticks)
        index = end < 0 ? index + ticks : end + ticks
        continue
      }
      if (text[index] !== delimiter[0]) { index++; continue }
      let count = 1
      while (text[index + count] === delimiter[0]) { count++ }
      const canClose = index > from && !/\s/.test(text[index - 1])
      const canOpen = !/\s/.test(text[index + count] || ' ')
      let remaining = count
      let consumed = 0
      while (canClose && stack.length > 0 && remaining >= stack[stack.length - 1]) {
        const top = stack[stack.length - 1]
        // A paired marker inside italic text starts/ends strong text as a pair.
        if (top === 1 && remaining % 2 === 0) { break }
        if (stack.length === 1) { return index + consumed }
        stack.pop()
        consumed += top
        remaining -= top
      }
      if (canOpen && remaining > 0 && (delimiter[0] !== '~' || remaining >= 2)) {
        stack.push(Math.min(remaining, delimiter[0] === '~' ? 2 : 3))
      }
      index += count
    }
    return -1
  }

  private parseInline(text: string, depth: number): MarkdownSpan[] {
    const spans: MarkdownSpan[] = []
    if (depth > MarkdownParser.MAX_DEPTH) {
      const literal = new MarkdownSpan()
      literal.text = text
      return [literal]
    }
    let plain = ''
    let i = 0
    while (i < text.length) {
      const ch = text[i]
      if (ch === '\\' && i + 1 < text.length && /[!"#$%&'()*+,\-./:;<=>?@[\]\\^_`{|}~\n]/.test(text[i + 1])) {
        plain += text[i + 1]
        i += 2
        continue
      }
      let consumed = 0
      let tokens: MarkdownSpan[] = []
      if (ch === '`') {
        let size = 1
        while (text[i + size] === '`') {
          size++
        }
        let end = text.indexOf('`'.repeat(size), i + size)
        while (end >= 0 && (text[end - 1] === '`' || text[end + size] === '`')) {
          end = text.indexOf('`'.repeat(size), end + size)
        }
        if (end >= 0) {
          const span = new MarkdownSpan()
          span.code = true
          let literal = text.slice(i + size, end).replace(/\n/g, ' ')
          if (literal.startsWith(' ') && literal.endsWith(' ') && literal.trim().length > 0) {
            literal = literal.slice(1, -1)
          }
          span.text = literal
          tokens = [span]
          consumed = end + size - i
        } else {
          plain += '`'.repeat(size)
          i += size
          continue
        }
      } else if (ch === '[' || (ch === '!' && text[i + 1] === '[')) {
        const image = ch === '!'
        const start = i + (image ? 2 : 1)
        let end = start
        let brackets = 1
        while (end < text.length && brackets > 0) {
          if (text[end] === '\\') {
            end += 2
            continue
          }
          if (text[end] === '[') { brackets++ }
          if (text[end] === ']') { brackets-- }
          if (brackets > 0) { end++ }
        }
        if (brackets === 0) {
          let url = ''
          let tail = end + 1
          if (text[tail] === '(') {
            let cursor = tail + 1
            let parentheses = 1
            while (cursor < text.length && parentheses > 0) {
              if (text[cursor] === '\\') { cursor += 2; continue }
              if (text[cursor] === '(') { parentheses++ }
              if (text[cursor] === ')') { parentheses-- }
              if (parentheses > 0) { cursor++ }
            }
            if (parentheses === 0) {
              const destination = text.slice(tail + 1, cursor).trim()
              const match = /^(?:<([^>]+)>|(\S+?))(?:\s+["'].*["'])?$/.exec(destination)
              if (match !== null) {
                url = match[1] || match[2]
                tail = cursor + 1
              }
            }
          } else {
            let name = text.slice(start, end)
            if (text[tail] === '[') {
              const referenceEnd = text.indexOf(']', tail + 1)
              if (referenceEnd >= 0) {
                name = text.slice(tail + 1, referenceEnd) || name
                tail = referenceEnd + 1
              }
            }
            const reference = this.references.get(name.trim().toLowerCase())
            if (reference !== undefined) { url = reference.url }
          }
          if (url.length > 0) {
            tokens = image ? [new MarkdownSpan()] : this.parseInline(text.slice(start, end), depth + 1)
            tokens.forEach((span: MarkdownSpan) => {
              span.url = MarkdownParser.safeUrl(this.decode(url.replace(/\\([()])/g, '$1')))
              span.image = image && span.url.length > 0
              if (image) { span.text = this.decode(text.slice(start, end)) || '图片' }
            })
            consumed = tail - i
          }
        }
      } else if (ch === '<') {
        const link = /^<(https?:\/\/[^<>\s]+)>/i.exec(text.slice(i))
        if (link !== null) {
          const span = new MarkdownSpan()
          span.text = this.decode(link[1])
          span.url = MarkdownParser.safeUrl(span.text)
          tokens = [span]
          consumed = link[0].length
        } else {
          const br = /^<br\s*\/?\s*>/i.exec(text.slice(i))
          if (br !== null) { plain += '\n'; i += br[0].length; continue }
        }
      } else if ((ch === 'h' || ch === 'H') && (i === 0 || /[\s(]/.test(text[i - 1]))) {
        const link = /^https?:\/\/[^\s<>]+/i.exec(text.slice(i))
        if (link !== null) {
          let url = link[0].replace(/[.,!?;:，。！？；：]+$/, '')
          while (url.endsWith(')') && url.split(')').length > url.split('(').length) {
            url = url.slice(0, -1)
          }
          const span = new MarkdownSpan()
          span.text = this.decode(url)
          span.url = MarkdownParser.safeUrl(span.text)
          tokens = [span]
          consumed = url.length
        }
      } else if (ch === '*' || ch === '_' || (ch === '~' && text[i + 1] === '~')) {
        let size = ch === '~' ? 2 : (text[i + 1] === ch ? (text[i + 2] === ch ? 3 : 2) : 1)
        const intraword = ch === '_' && i > 0 && /[\w]/.test(text[i - 1])
        if (!intraword && !/\s/.test(text[i + size] || ' ')) {
          const end = this.closingDelimiter(text, ch.repeat(size), i + size)
          if (end >= 0) {
            tokens = this.parseInline(text.slice(i + size, end), depth + 1)
            tokens.forEach((span: MarkdownSpan) => {
              span.bold = span.bold || (ch !== '~' && size >= 2)
              span.italic = span.italic || (ch !== '~' && size !== 2)
              span.strike = span.strike || ch === '~'
            })
            consumed = end + size - i
          }
        }
      }
      if (consumed > 0) {
        if (plain.length > 0) {
          const span = new MarkdownSpan()
          span.text = this.decode(plain.replace(/ {2,}\n/g, '\n'))
          spans.push(span)
          plain = ''
        }
        spans.push(...tokens)
        i += consumed
      } else {
        plain += ch
        i++
      }
    }
    if (plain.length > 0) {
      const span = new MarkdownSpan()
      span.text = this.decode(plain.replace(/ {2,}\n/g, '\n'))
      spans.push(span)
    }
    return spans
  }
}
