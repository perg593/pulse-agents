export type TagOption = {
  id: number
  text: string
  color: string
}

export type MultipleSelectionFilterOption = {
  label: string
  value: any
}

export type Tag = {
  appliedTagId: number
  id: number
  text: string
  tagApproved: boolean
  color: string
}

export type Question = {
  autotagEnabled: boolean
  content: string
  id: number
}

export type Answer = {
  id: number
  textResponse: string
  tags: Tag[]
  sentiment: string
  createdAt: string
  completionUrl: string
  deviceType: string
  customData: Object
  deviceData: Object[]
  translation: string
}

export type UpdatedRowValue = {
  rowIndex: number
  columnId: string
  value: any
}

export type AutoTagAnswersResponseTags = {
  id: number
  answerId: number
  appliedTagId: number
  name: string
  color: string
}
