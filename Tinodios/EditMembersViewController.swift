//
//  EditMembersViewController.swift
//  Tinodios
//
//  Copyright © 2019 Tinode. All rights reserved.
//

import UIKit
import TinodeSDK

public protocol EditMembersDelegate: class {
    // Asks for the UIDs of initially selected members
    func editMembersInitialSelection(_: UIView) -> [String]
    // Called when the editor completes selection.
    func editMembersDidEndEditing(_: UIView, added: [String], removed: [String])
    // Called when member is added or removed. Return 'true' to continue, 'false' to reject the change.
    func editMembersWillChangeState(_: UIView, uid: String, added: Bool, initiallySelected: Bool) -> Bool
}

class EditMembersViewController: UIViewController, UITableViewDataSource {
    private var contactsManager = ContactsManager()
    private var contacts: [ContactHolder]!
    private var selectedContacts = [IndexPath]()
    private var initialIds = Set<String>()
    private var selectedIds = Set<String>()

    private weak var delegate: EditMembersDelegate?

    @IBOutlet var editMembersView: UIView!
    @IBOutlet weak var membersTableView: UITableView!
    @IBOutlet weak var selectedCollectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.membersTableView.dataSource = self
        self.membersTableView.allowsMultipleSelection = true
        self.membersTableView.delegate = self
        self.membersTableView.register(UINib(nibName: "ContactViewCell", bundle: nil), forCellReuseIdentifier: "ContactViewCell")

        self.selectedCollectionView.dataSource = self
        self.selectedCollectionView.register(UINib(nibName: "SelectedMemberViewCell", bundle: nil), forCellWithReuseIdentifier: "SelectedMemberViewCell")

        setup()
    }

    private func setup() {
        guard let subscriptions = delegate?.editMembersInitialSelection(editMembersView) else { return }
        for uid in subscriptions {
            selectedIds.insert(uid)
            initialIds.insert(uid)
        }
        for i in 0..<contacts.count {
            let c = contacts[i]
            if let uid = c.uniqueId, userSelected(with: uid) {
                selectedContacts.append(IndexPath(row: i, section: 0))
            }
        }
        // isAdmin = topic.isAdmin
        // self.navigationItem.title = topic.pub?.fn ?? "Unknown"
    }
    func addUser(with uniqueId: String) {
        self.selectedIds.insert(uniqueId)
    }
    func removeUser(with uniqueId: String) {
        self.selectedIds.remove(uniqueId)
    }
    func userSelected(with uniqueId: String) -> Bool {
        return self.selectedIds.contains(uniqueId)
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactViewCell", for: indexPath) as! ContactViewCell

        // Configure the cell...
        let contact = contacts[indexPath.row]

        cell.avatar.set(icon: contact.image, title: contact.displayName, id: contact.uniqueId)
        cell.title.text = contact.displayName
        cell.title.sizeToFit()
        cell.subtitle.text = contact.subtitle ?? contact.uniqueId
        cell.subtitle.sizeToFit()
        cell.accessoryType = cell.isSelected ? .checkmark : .none

        // Data reload clears selection. If we already have any selected users,
        // select the corresponding rows in the table.
        if let uniqueId = contact.uniqueId, self.userSelected(with: uniqueId) {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            cell.accessoryType = .checkmark
        }

        return cell
    }
    @IBAction func saveClicked(_ sender: Any) {
        self.updateGroup()
        self.navigationController?.popViewController(animated: true)
        self.dismiss(animated: true, completion: nil)
    }
    private func getDeltas() -> ([String], [String]) {
        let additions = selectedIds.subtracting(initialIds)
        let deletions = initialIds.subtracting(selectedIds)
        return (additions.map { $0 }, deletions.map { $0 })
    }
    func updateGroup() {
        let deltas = getDeltas()
        let additions = deltas.0
        let deletions = deltas.1

        delegate?.editMembersDidEndEditing(editMembersView, added: additions, removed: deletions)
        /*
        print("inviting \(additions)")
        for uid in additions {
            _ = try? topic.invite(user: uid, in: nil)?.then(
                onSuccess: nil, onFailure: UiUtils.ToastFailureHandler)
        }
        print("ejecting \(deletions)")
        for uid in deletions {
            _ = try? topic.eject(user: uid, ban: false)?.then(
                onSuccess: nil, onFailure: UiUtils.ToastFailureHandler)
        }
        */
    }
}

extension EditMembersViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let uid = contacts[indexPath.row - 1].uniqueId else {
            print("no unique id for user at \(indexPath.row - 1)")
            return nil
        }

        return delegate?.editMembersWillChangeState(editMembersView, uid: uid, added: true, initiallySelected: initialIds.contains(uid)) ?? true ? indexPath : nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let uid = contacts[indexPath.row - 1].uniqueId else {
            print("no unique id for user at \(indexPath.row - 1)")
            return
        }

        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        print("selected index path = \(indexPath)")
        self.addUser(with: uid)
        selectedContacts.append(indexPath)
        selectedCollectionView.insertItems(at: [IndexPath(item: selectedContacts.count - 1, section: 0)])
        print("+ selected rows: \(self.selectedIds)")
    }

    func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let uid = contacts[indexPath.row - 1].uniqueId else {
            print("no unique id for user at \(indexPath.row - 1)")
            return indexPath
        }

        return delegate?.editMembersWillChangeState(editMembersView, uid: uid, added: false, initiallySelected: initialIds.contains(uid)) ?? true ? indexPath : nil
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let uid = contacts[indexPath.row - 1].uniqueId else {
            print("no unique id for user at \(indexPath.row - 1)")
            return
        }

        tableView.cellForRow(at: indexPath)?.accessoryType = .none
        self.removeUser(with: uid)
        if let removeAt = selectedContacts.firstIndex(of: indexPath) {
            selectedContacts.remove(at: removeAt)
            selectedCollectionView.deleteItems(at: [IndexPath(item: removeAt, section: 0)])
        }
        print("- selected rows: \(self.selectedIds)")
    }
}

extension EditMembersViewController : UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        //toggleNoSelectedMembersNote(on: selectedContacts.isEmpty)
        return selectedContacts.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SelectedMemberViewCell", for: indexPath) as! SelectedMemberViewCell
        let contact = contacts[selectedContacts[indexPath.item].item]
        cell.avatarImageView.set(icon: contact.image, title: contact.displayName, id: contact.uniqueId)
        return cell
    }
}
